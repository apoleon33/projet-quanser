% SETUP QUANSER QBOT
caseNum = 3; % 1, 2, 3, or 4

slipmat = false;

system('quanser_host_peripheral_client.exe -q');
pause(2)
system('quanser_host_peripheral_client.exe  -uri tcpip://localhost:18444 &');

% MATLAB Path

newPathEntry = fullfile(getenv('QAL_DIR'), '0_libraries', 'matlab', 'qvl');
pathCell = regexp(path, pathsep, 'split');
if ispc  % Windows is not case-sensitive
  onPath = any(strcmpi(newPathEntry, pathCell));
else
  onPath = any(strcmp(newPathEntry, pathCell));
end

if onPath == 0
    path(path, newPathEntry)
    savepath
end

% Stop RT models
try
    qc_stop_model('tcpip://localhost:17000', 'qbot_platform_driver_virtual')
    pause(1)
    qc_stop_model('tcpip://localhost:17000', 'QBotPlatform_Workspace')
catch error
end
pause(1)

% QLab connection
qlabs = QuanserInteractiveLabs();
connection_established = qlabs.open('localhost');

if connection_established == false
    disp("Failed to open connection. Are you sure Quanser QLab is running ?")
    return
end
disp('Connected to Quanser Qlab?')
verbose = true;
num_destroyed = qlabs.destroy_all_spawned_actors();

% Tapis
% if slipmat == true
%     hFloor0 = QLabsQBotPlatformFlooring(qlabs);
%     % center
%     hFloor0.spawn_id(0, [-0.6, 0.6,   0], [0,0,-pi/2], [1,1,1], 5, false); 
%     % corners
%     hFloor0.spawn_id(1, [ 0.6, 1.8,   0], [0,0,-pi/2], [1,1,1], 0, false);
%     hFloor0.spawn_id(2, [ 1.8,-0.6,   0], [0,0, pi  ], [1,1,1], 0, false);
%     hFloor0.spawn_id(3, [-0.6,-1.8,   0], [0,0, pi/2], [1,1,1], 0, false);
%     hFloor0.spawn_id(4, [-1.8, 0.6,   0], [0,0,    0], [1,1,1], 0, false);
%     % sides
%     hFloor0.spawn_id(5, [-0.6, 0.6,   0], [0,0,    0], [1,1,1], 5, false);
%     hFloor0.spawn_id(6, [ 0.6, 0.6,   0], [0,0,-pi/2], [1,1,1], 5, false);
%     hFloor0.spawn_id(7, [ 0.6,-0.6,   0], [0,0, pi  ], [1,1,1], 5, false);
%     hFloor0.spawn_id(8, [-0.6,-0.6,   0], [0,0, pi/2], [1,1,1], 5, false);
% end

% Définir les Waypoints [x, y, theta]
waypoints = [
    0,    0,    0;          % Point de départ
    %0.1,  0,    -pi/6
    %2.25, -1, 0;
    3.5, 0, pi/2;
    3.5,    2.5,    deg2rad(100);
    %2.5,    3.5,    pi;
    0,    0,  0         % Arrivée
];

% Obstacles Circulaires [x, y, rayon]
obstacles = [
     % 2, -0.1, 0.0 ; 
     1.5, 1.5, 0;
     2.25, 0, 0.5;
];

% waypoints
waypointsObj = QLabsBasicShape(qlabs, verbose);

% startpoint
[~, startpoint] = waypointsObj.spawn([waypoints(1,1), waypoints(1,2),0], [0,0,waypoints(1,3)], [0.1,0.3,1], QLabsBasicShape.SHAPE_CUBE);
waypointsObj.actorNumber = startpoint;
waypointsObj.set_enable_collisions(false);
waypointsObj.set_material_properties([0.0, 0.0, 0.7]);

% waypoints intermediaire
for w = waypoints(2:end-1, :)' % le ' inverse lignes et colonnes
    [~, way] = waypointsObj.spawn([w(1),w(2),0], [0,0,w(3)], [0.1,0.3,1], QLabsBasicShape.SHAPE_CUBE);
    waypointsObj.actorNumber = way;
    waypointsObj.set_enable_collisions(false);
    waypointsObj.set_material_properties([0.0, 0.7, 0.7]);
end

% Arrivee
[~, fin] = waypointsObj.spawn([waypoints(end, 1),waypoints(end, 2),0], [0,0, waypoints(end, 3)], [0.1,0.3,1], QLabsBasicShape.SHAPE_CUBE);
waypointsObj.actorNumber = fin;
waypointsObj.set_enable_collisions(false);
waypointsObj.set_material_properties([0.0, 0.7, 0.0]);


% Obstacles
obstaclesObj = QLabsBasicShape(qlabs, verbose);

for obs = obstacles'
    obstaclesObj.spawn([obs(1), obs(2), 0], [0,0,0], [obs(3),obs(3),1], QLabsBasicShape.SHAPE_CYLINDER);
end


% QBot
hQBot = QLabsQBotPlatform(qlabs, verbose);
location = [0, 0, 0; -1.35, 0.3, 0; -1.5, 0, 0; -1.5, 0, 0];
rotation = [0, 0, 0;    0,   0, 0;   0, 0, 90;  0, 0, -90];
    hQBot.spawn_id_degrees(0, [waypoints(1,1), waypoints(1,2), 0], [0,0,rad2deg(waypoints(1,3))], [1, 1, 1], 1) ;
    hQBot.possess(hQBot.VIEWPOINT_TRAILING);

    file_workspace = fullfile(getenv('RTMODELS_DIR'), 'QBotPlatform', 'QBotPlatform_Workspace.rt-win64');
    file_driver    = fullfile(getenv('RTMODELS_DIR'), 'QBotPlatform', 'qbot_platform_driver_virtual.rt-win64');


% Start RT models
pause(2)
system(['quarc_run -D -r -t tcpip://localhost:17000 ', file_workspace]);
pause(1)
system(['quarc_run -D -r -t tcpip://localhost:17000 ', file_driver, ' -uri tcpip://localhost:17098']);
pause(3)

% VARIABLES UTILISE DANS SIMULINK
%parametre de la simulation
T_sim = 100;                     %Durée de la simulation 
dt = 0.01;                      % Pas de la simulation ( en terme de temps)
time = 0:dt:T_sim;

%Paramètres du controleur ( le fameux "Gain Schduling" du paper)
zeta = 0.7;                     % sqrt(2)/2 cf cours
g = 10;                         % Gain de liberté pour k2

% Conditions initiales du Robot (x, y, theta) 
x0 =  waypoints(1,1);
y0 =  waypoints(1,2);                      
theta0 = rad2deg(waypoints(1,3));

L = 0.390; % entraxe
R = 0.044; % rayon des roues
