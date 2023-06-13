
--load road network data from osm using osm2pgrouting

osm2pgrouting -f ../project/map.osm  -h localhost -U postgres -d sanmarcos -p 5432 -W password-here --conf= mapconfig.xml 
	
-- add indexes (tried these queries, but the indxes were already there, created by the import tool)
CREATE INDEX ways_geom_idx ON ways USING gist (the_geom);
CREATE INDEX ways_source_idx ON roads (source);
CREATE INDEX ways_target_idx ON roads (target);
	
-- check that routing works
SELECT seq, node, edge, rt.cost, w.the_geom as geom
	FROM pgr_dijkstra('
		SELECT gid as id, source, target,length as cost FROM ways',
        1301, 5955, false
        )as rt
JOIN ways w ON rt.edge = w.gid;

-- test routing with coordinates
SELECT seq, node, edge, rt.cost, w.the_geom as geom
    FROM pgr_dijkstra('
       SELECT gid as id, source, target,length as cost FROM ways',
				-- get the id of the start node closest to coordinates
                (SELECT source FROM ways
    				ORDER BY ST_Distance(
        				ST_StartPoint(the_geom),
       					ST_SetSRID(ST_MakePoint(-97.920094, 29.873404), 4326),
       					true
   					) ASC
   					LIMIT 1),
				-- get the id of the end node closest to coordinates
				(SELECT source FROM ways
    				ORDER BY ST_Distance(
        				ST_StartPoint(the_geom),
       					ST_SetSRID(ST_MakePoint(-97.942180, 29.886261), 4326),
       					true
   					) ASC
   					LIMIT 1), false
       			 )as rt
JOIN ways w ON rt.edge = w.gid;	

--------------------------------------------------------------------------------------------------------------------------	
-- It is possible to load roads from a shapefile too and then turn it into a network, but it didn't work well for me	
-- After loading shp to postgis this would be the workflow:

-- add columns to store info about the nodes and the cost (length in this case)	
ALTER TABLE roads ADD COLUMN source INTEGER;  
ALTER TABLE roads ADD COLUMN target INTEGER;  
ALTER TABLE roads ADD COLUMN length FLOAT8;  

-- create topology
SELECT pgr_createTopology('roads',0.0001,'geom','gid'); 

-- add indexes
CREATE INDEX roads_geom_idx ON roads USING gist (geom);
CREATE INDEX roads_source_idx ON roads (source);
CREATE INDEX roads_target_idx ON roads (target);
UPDATE roads SET length = ST_Length(geom::geography);

-- check network validity
SELECT pgr_analyzeGraph('roads', 0.0001, 'geom','gid');
----------------------------------------------------------------------------------------------------------------------------
	
--import buildings data (https://github.com/Microsoft/USBuildingFootprints) using shapefile loader tool

--imported buildings then turned into centroids that will serve as startpoints for navigation.

CREATE TABLE waypoints as select gid, ST_SetSRID(ST_ST_Centroid(geom),4326) geom from buildings;
CREATE INDEX waypoints_geom_idx ON waypoints USING gist (geom);

-- each  centroid should know the id of the closest road network node
ALTER TABLE waypoints ADD COLUMN node_id INTEGER;

UPDATE waypoints wp SET node_id = 
	(SELECT source FROM ways w
		ORDER BY ST_Distance(
			ST_StartPoint(w.the_geom),
			wp.geom,
			true
		) 
	ASC LIMIT 1)
-- this query took 34 min 12 secs.


--Before calculating all the routes, some graph cleaning required.
--I used Qgis plugin "Disconnected islands" to identify disconnected pieces of the network
 
--clean the data from disconnected pieces (networkgrp field created by the Qgis plugin)
DELETE FROM ways  WHERE networkgrp > 0;

--delete nodes that are not used anymore
DELETE
FROM   ways_vertices_pgr v 
WHERE  NOT EXISTS (
   SELECT 
   FROM   ways
   WHERE  v.id =target or v.id = source
   );

--some additional cleaning by built in pgRouting tool
SELECT pgr_analyzeGraph('ways', 0.0001, 'the_geom','gid');
--Check for the not connected edges (visually)
SELECT a.the_geom
    FROM ways a, ways_vertices_pgr b, ways_vertices_pgr c
    WHERE a.source=b.id AND b.cnt=1 AND a.target=c.id AND c.cnt=1;
-- Get rid of them
DELETE FROM ways where
	gid in (select a.gid
    FROM ways a, ways_vertices_pgr b, ways_vertices_pgr c
    WHERE a.source=b.id AND b.cnt=1 AND a.target=c.id AND c.cnt=1);
	
-- add a weight columnt to ways, to store weights later
ALTER TABLE ways ADD COLUMN weight INTEGER;  
  
-- After getting the data ready, two  functions needed for calclulating all the routs to ELA
-- first one calculates from each building centroid, another from each node in the graph 

CREATE  OR REPLACE FUNCTION roads_to_rome(focus int default 23429) RETURNS void AS $$ --takes focus point ID (destination point), returns nothing
DECLARE
waypoint_gid integer; --variable to hold current iteration starting waypoint ID
BEGIN
FOR waypoint_gid in -- iterate over all waypoints, except the destination one
        SELECT w.gid FROM waypoints w
				  WHERE w.gid != focus
           LOOP
				RAISE NOTICE 'calculating route from waypoint = %',waypoint_gid; -- console message to see that it is till working
				-- calc route from current start point to focus
				WITH route AS
				(SELECT  edge 
					FROM pgr_dijkstra(
						'SELECT gid as id, source, target,length as cost FROM ways',
						(SELECT node_id FROM waypoints WHERE gid = waypoint_gid),  -- current starting point of the route (closest node_id)
						(SELECT node_id FROM waypoints WHERE gid = focus),		   -- destination, the same for all routes (focus node_id)
						false											 
						)
				)
				--- add 1 to weigh column of the current route edges	
				UPDATE ways SET weight = weight+1
					FROM route
					WHERE ways.gid = route.edge;
			END LOOP;
END;
$$ LANGUAGE plpgsql;

--call the function
select roads_to_rome()
-- took 3 hr 54 min

--function to calculaete routs from every node of the network
CREATE  OR REPLACE FUNCTION roads_to_rome2(focus int default 8710) RETURNS void AS $$ --takes focus node ID (destination point), returns nothing
DECLARE
node_id integer;
counter integer = 0; 
BEGIN
FOR node_id in
        SELECT n.id FROM ways_vertices_pgr n
				  WHERE n.id != focus
           LOOP
                counter= counter+1;
				RAISE NOTICE 'calculating route from node % out of 13509',counter;
				-- calc route from current start point to focus
				WITH route AS
				(SELECT  edge 
					FROM pgr_dijkstra(
					'SELECT gid as id, source, target,length as cost FROM ways_by_node',
					 node_id,  -- current starting point of the route )
					 focus,		   -- destination, the same for all routes (focus node_id)
					 false											 
					)
				)
				--- add 1 to weigh column of the current route edges	
				UPDATE ways_by_node SET weight = weight+1
					FROM route
					WHERE ways_by_node.gid = route.edge;
				
			END LOOP;
END;
$$ LANGUAGE plpgsql;


roads_to_rome2()
--took 52 min 39 secs.  


----------------------------------------------------------------------