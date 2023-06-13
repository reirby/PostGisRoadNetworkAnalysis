Here are two road network analysis projects based on PostGIS and pgRouting.

### Betwenness Centrality
![image](/betweennessCentrality/img/5.jpeg)
Betweenness Centrality (BC) comes from the domain of social networks analysis but has been used to investigate and compare urban street networks as well (Strano et al. 2013; Wang 2015; Masucci and Molinero 2016; Boeing 2018). The research mentioned above use betweenness centrality to study the resilience of the road network, to compare cities to each other and to develop a classification for identifying similar cities in large collections. BC was used both for comparing and classification of different cities (Wang 2015; Boeing 2018) and for investigating the properties of a single city (Scellato et al. 2006; Murphy, Levinson, and Owen 2015). This network measure is designed to address the question of identifying the importance of segments (or nodes) in large complex networks (Barthelemy 2004).  The segment is considered important if it is included in many of the shortest paths connecting pairs of nodes. In other words, important segments of the road network are the streets that are structurally made to be traversed more often.
For the sake of reducing processing time, we use of a modified version of BC, reduced to
$$g(v)=  \sum_{s \ne v \ne t} σ_{st} (v) $$
where $σ_{st}$ is the total number of shortest paths from node $s$ to node $t$ and $σ_{st} (v)$ is the number of shortest paths from $s$ to $t$ going through $v$. The resulting weighted road network can be visualized in QGIS using the calculated betweenness centrality metric as a base for a custom visualization style. Since the weights of the road segments vary from 0 and for the roads on the periphery to the hundreds of thousands for the highly used segments, a logarithmic scale is recommended to display the values of BC on the map.

Flowchart of the data processing (similar for both projects):

![image](/betweennessCentrality/img/diagram.png)

### All roads lead to Rome
The second project is an implementation of the "All roads lead to Rome" road network [visualization](http://web.archive.org/web/20201102165714/https://www.move-lab.com/project/roadstorome/).
In Ancient Rome there was a monument, The Golden Milestone. All roads were considered to begin at this monument and all distances in the Roman Empire were measured relative to it. The provided code allows calculation of a road network visualizzation for any specified central point.
![image](https://github.com/reirby/PostGisRoadNetworkAnalysis/assets/18068801/bcbf5ce6-3555-4cdc-8290-c7cf2414635b)






References
Barthelemy, M. 2004. Betweenness centrality in large complex networks. The European physical journal B 38 (2):163–168.
Boeing, G. 2018. A multi-scale analysis of 27,000 urban street networks: Every US city, town, urbanized area, and Zillow neighborhood. Environment and Planning B: Urban Analytics and City Science :2399808318784595.
Masucci, A. P., and C. Molinero. 2016. Robustness and closeness centrality for self-organized and planned cities. The European Physical Journal B 89 (2):53.
Murphy, B., D. Levinson, and A. Owen. 2015. Accessibility and Centrality Based Estimation of Urban Pedestrian Activity.
Scellato, S., A. Cardillo, V. Latora, and S. Porta. 2006. The backbone of a city. The European Physical Journal B-Condensed Matter and Complex Systems 50 (1–2):221–225.
Strano, E., M. Viana, L. da Fontoura Costa, A. Cardillo, S. Porta, and V. Latora. 2013. Urban street networks, a comparative analysis of ten European cities. Environment and Planning B: Planning and Design 40 (6):1071–1086.
Wang, J. 2015. Resilience of self-organised and top-down planned cities—a case study on London and Beijing street networks. PloS one 10 (12):e0141736.
Wang, Z., M. Lu, X. Yuan, J. Zhang, and H. Van De Wetering. 2013. Visual traffic jam analysis based on trajectory data. IEEE transactions on visualization and computer graphics 19 (12):2159–2168.
