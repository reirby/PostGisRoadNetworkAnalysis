Betwennes centrality PostgreSQL project

-- make a new table as a copy of imported road network
create table source_roads as select * from ways_by_node;

--crop by the san marcos city limits extent
--get rid of the disconnected pieces of road network
--Use Qgis tools

--create topology
SELECT  pgr_createTopology('source_roads', 0.00001,'the_geom', 'gid', 'source', 'target',  clean := true); 
SELECT pgr_analyzeGraph('source_roads',0.00001, 'the_geom','gid');

-- get rid of unnecessary nodes (was 7203, 6241 left) 

-- mark segments for merging
DO
$do$
declare 
node_id int;
BEGIN
FOR node_id in  select id from source_roads_vertices_pgr WHERE cnt = 2

	LOOP
		IF (select count( distinct networkgrp) from source_roads where source = node_id or target = node_id) < 2 THEN
	       	update source_roads
			set networkgrp = node_id
			WHERE source = node_id or target = node_id;
		ELSE 
			update source_roads
			set networkgrp = (select networkgrp from source_roads WHERE source = node_id or target = node_id ORDER BY networkgrp DESC limit 1)
			WHERE source = node_id or target = node_id;
     	END IF;
		
						
	END LOOP;
	end;
	$do$

-- merge segments marked 
DO
$do$
declare 
curr_networkgrp int;
BEGIN
FOR curr_networkgrp in select networkgrp from source_roads WHERE networkgrp != 0

	LOOP
		update source_roads set the_geom = 
		ST_LineMerge( ( select ST_Union(the_geom) from source_roads where networkgrp  = curr_networkgrp ) )
		where networkgrp = curr_networkgrp;
						
	END LOOP;
end;
$do$

--- check that there are duplicate segments after joining
SELECT
    the_geom,
    COUNT( the_geom )
FROM
    source_roads
GROUP BY
    the_geom
HAVING
    COUNT( the_geom )> 1
ORDER BY
    the_geom;

--get rid of the all extra ones
DELETE
FROM
    source_roads a
        USING source_roads b
WHERE
    a.gid < b.gid
    AND a.the_geom = b.the_geom;


-- recreate topology 

SELECT  pgr_createTopology('source_roads', 0.00001,'the_geom', 'gid', 'source', 'target',  clean := true); 
SELECT pgr_analyzeGraph('source_roads',0.00001, 'the_geom','gid');

-- update lengh of the segments
UPDATE source_roads SET length = ST_Length(the_geom::geography);

--add indexes, vacuum 
CREATE INDEX source_roads_geom_idx ON source_roads USING gist (the_geom);
REINDEX INDEX source_roads_source_idx;
REINDEX INDEX source_roads_target_idx;

VACUUM(FULL, ANALYZE) source_roads;

--- Caculate new table of everywhere to everywhere routes using dijkstra many to many
create table ete as 
	SELECT edge, w.the_geom as geom
	FROM pgr_dijkstra(
		'SELECT gid as id,source,target,length as cost FROM source_roads', 
		ARRAY(SELECT i.id FROM source_roads_vertices_pgr i ),
		ARRAY(SELECT j.id FROM source_roads_vertices_pgr j ),
		FALSE)
	as rt
JOIN source_roads w ON rt.edge = w.gid;

-- Count the number of the segments with the same ID and assign the count as weight
WITH w AS (
	SELECT    gid,
    COUNT( gid )
    FROM ete
    GROUP BY gid
)
update source_roads
set weight = w.count
from w
where source_roads.gid = w.gid;