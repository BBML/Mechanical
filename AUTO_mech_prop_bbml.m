function [ ]  = AUTO_mech_prop_bbml()

tic
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% VERSION NOTES
% !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
% THIS CODE IS FOR MEMBERS OF BBML
% It imports I and c values from excel sheet generated by Mech_geom_bbml
% IT WILL NOT WORK WITH EXCEL SHEETS MADE BY CTgeom_bbml
% !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

% Jan 2020 RKK made this a batch-process code. The code now automatically
% finds start, stop, and modulus of the data, no longer requiring the user
% to select points. HOWEVER:

%*************************************************************************
% It is recommended that the user always go through the output plots to 
% ensure data was processed correctly. Data with poorly selected points  
% should be manually re-processed with Mech_prop_bbml.m.
%*************************************************************************

% RKK adapted on 10/4/2019 to fix geometry inputs and allow for both femur 
% and tibia testing.

% AGB adapted on 7/24/15 to not zero the load and displacement when you choose
% the start point due to problems with rolling during testing. Instead, the
% program will use this point, then perform a linear regression to take
% this back to 0,0
%
% Edited by Max Hammond Sept. 2014 Changed the output from a csv 
% file to an xls spreadsheet that included a title row. Code written by
% Alycia Berman was added into the CTgeom section of the code to subtract
% out the scale bars that appear in some CT images. Used while loop to
% semi-batch process. Hard coded in initial values like bendtype, slice
% number, and voxel size because each will be held constant within a study.
% Added the option to smooth or not during Testing Configuration. Smoothed
% using a moving average with a span of 10. Added a menu in case points
% need to be reselected.

% Written by Joey Wallace, July 2012 to work with test resources system.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PROGRAM DESCRIPTION
% This is a comprehensive program that reads in geometric and mechanical
% information to calculate force/displacement and stress/strain from 
% bending mechanical tests (3 OR 4 POINT).

% This program reads raw mechanical data from the a file generated by the 
% Bose system. There is no naming convention for files, but names for data
% files must match the corresponding list in the CT_geom output.

% For femora, the assumption is that bending was about the ML 
% axis with  the anterior surface in tension. For tibiae, the assumption is
% that bending was about the AP axis with the medial surface in tension.

% The program adjusts for system compliance and then uses beam bending
% theory to convert force-displacement data to theoretical stress-strain
% values.  Mechanical properties are calculated in both domains and output
% to a file "StudyName_SpecimenType_mechanics.csv".  It also outputs 
% a figure showing the load-displacement and stress-strain curves with 
% significant points marked.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%close all figure windows and clears all variables
close all
clear all
dbstop if error

%*****************\TESTING CONFIGURATION/**********************************
%                                                                         *
%   Adjust these values to match the system setup.                        *
%                                                                         *
L = 9.00;           %span between bottom load points (mm)                 *
a = 4.00;           %distance between outer and inner points (if 4pt; mm) *
bendtype = '4';     %enter '4' for 4pt and '3' for 3pt bending            *
compliance = 0;     %system compliance (microns/N)                        *
side = 'R';         %input 'R' for right and 'L' for left                 *
bone = 'T';         %enter 'F' for femur and 'T' for tibia                *
smoothing = 1;      %enter 1 to smooth using moving average (span=10)     *
study = 'test_';    %enter study label for output excel sheet (eg 'STZ_') *
%**************************************************************************

%Check common errors in testing configuration
if bendtype ~= '3' && bendtype ~= '4'
        error('Please enter 3 or 4 for bendtype as a string in the Testing Configuration')
end

if strcmp(side,'L') == 0 && strcmp(side,'R') == 0
        error('Please enter R or L for side as a string in the Testing Configuration')
end

if smoothing ~= 1 && smoothing ~= 0
        error('Please enter a 1 or 0 for smoothing in the Testing Configuration')
end

if bone ~= 'F' && bone ~= 'T'
        error('Please F or T for bone as a string in the Testing Configuration')
end

if bone == 'T' && bendtype == '3'
        error('Tibias are tested in 4 pt bending. Please change bendtype to 4.')
end

% RKK added final check to ensure that user edits testing configuration values
answer = questdlg('Have you modified the testing configuration values?', ...
	'Sanity Check', ...
	'Yes','No','Huh?','Huh?');
% Handle response
switch answer
    case 'Yes'
    case 'No'
        disp([answer '. Please edit testing configuration values.'])
        return
    case 'Huh?'
        disp([answer ' See line 69 in the code. Please edit testing configuration values.'])
        return
end

% Predefine variables and create output file
ppp=2;
bonetype = [side bone];
xls=[study bonetype '_mechanics.xls'];

if bone == 'T'
    headers = {'Specimen','I_ap (mm^4)','c_med (µm)','Yield Force (N)','Ultimate Force (N)','Displacement to Yield (µm)','Postyield Displacement (µm)','Total Displacment (µm)','Stiffness (N/mm)','Work to Yield (mJ)','Postyield Work (mJ)','Total Work (mJ)','Yield Stress (MPa)','Ultimate Stress (MPa)','Strain to Yield (µ?)','Total Strain (µ?)','Modulus (GPa)','Resilience (MPa)','Toughness (MPa)',' ','Specimen','Yield Force (N)','Ultimate Force (N)','Failure Force (N)','Displacement to Yield (µm)','Ultimate Displacement (µm)','Total Displacment (µm)','Yield Stress (MPa)','Ultimate Stress (MPa)','Failure Stress (MPa)','Strain to Yield (µ?)','Ultimate Strain (µ?)','Total Strain (µ?)'};
elseif bone == 'F'
    headers = {'Specimen','I_ml (mm^4)','c_ant (µm)','Yield Force (N)','Ultimate Force (N)','Displacement to Yield (µm)','Postyield Displacement (µm)','Total Displacment (µm)','Stiffness (N/mm)','Work to Yield (mJ)','Postyield Work (mJ)','Total Work (mJ)','Yield Stress (MPa)','Ultimate Stress (MPa)','Strain to Yield (µ?)','Total Strain (µ?)','Modulus (GPa)','Resilience (MPa)','Toughness (MPa)',' ','Specimen','Yield Force (N)','Ultimate Force (N)','Failure Force (N)','Displacement to Yield (µm)','Ultimate Displacement (µm)','Total Displacment (µm)','Yield Stress (MPa)','Ultimate Stress (MPa)','Failure Stress (MPa)','Strain to Yield (µ?)','Ultimate Strain (µ?)','Total Strain (µ?)'};
end

xlswrite(xls, headers, 'Data', 'A1')
warning off MATLAB:xlswrite:AddSheet

% Get CT Data
[CT_filename, CT_pathname] = uigetfile({'*.xls;*.xlsx;*.csv','Excel Files (*.xls,*.xlsx,*.csv)'; '*.*',  'All Files (*.*)'},'Pick the file with CT info');
[~,~,CT_Data] = xlsread([CT_pathname CT_filename],'Raw Data');
specimen_list=CT_Data(2:end,1);

% Cycle through specimen numbers
for kkk=1:length(specimen_list)

specimen_name=specimen_list{kkk};
ID = specimen_name;

%Checks if mechanical file exists

if isfile([ID '.csv'])
    
clear load_extension disp_extension y_offset x_offset slope1

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%This is where we pull in data from the CT, the row for I and c are critical.

CT_Data_Row = find(strcmp(CT_Data,ID));

if bone == 'T'
    I =   CT_Data{CT_Data_Row,2}; %I_ap          
    c =   CT_Data{CT_Data_Row,3}*1000; %c_med
elseif bone == 'F'
    I =   CT_Data{CT_Data_Row,5}; %I_ml         
    c =   CT_Data{CT_Data_Row,6}*1000; %c_ant
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Read in raw mechanical testing data generated by Bose system
imported_data = csvread([ID '.csv'],5,0);
load = imported_data (:,3);         %in N
load = load*(-1);
position = imported_data (:,2);     %in mm
position = position * 10^3 * (-1);         %in microns

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Moving average smoothing with span of 10 if selected initially
if smoothing == 1
    load = smooth(load,10,'moving');
end

%Plot initial data set for comparison with final truncated set
figure ()
plot(position,load,'--k')
xlabel ('Displacement (microns)')
ylabel ('Force (N)')
hold on

% Find elastic modulus region ---------------------------------------------
ultimate_load = max(load);
i=5;
j=10;
y=load(1:i);
x=position(1:i);

% Sample slope values before ultimate load
while y<ultimate_load
    fit=polyfit(x,y,1);
    % Avoid including "bumps" as slope samples
    if fit(1)>0.01
    slope1(i)=fit(1);
    end
    % Go to next set of points
    y=load(i:j);
    x=position(i:j);
    i=i+5;
    j=j+5;
end

% Select the top 30 slope values and average them. 
slope2=slope1;
m=zeros(1,30);

for i=1:30
    [k,j]=max(slope2);
    slope2(j)=0;
    m(i)=k;
end

slope=mean(m);

% Find start point -------------------------------------------------------
mt=slope1(1);
count1=1;

while mt<m(30)
    count1=count1+1;
    mt=slope1(count1);
end

% Truncate beginning of data
load=load(count1:end);
position=position(count1:end);

% Extrapolate missing load-displacement data
load_extension(1)=0;
disp_extension(1)=0;
i=1;

while load_extension(i)<load(1)
    i=i+1;
    disp_extension(i)=i-1;
    load_extension(i)=disp_extension(i)*slope;
end

position=position+disp_extension(end)-position(1);
position=[disp_extension'; position];
load=[load_extension';load];

% Find failure point ----------------------------------------------------
% End is defined by curve moving backwards (load cell "returning")
[ultimate_load,p] = max(load);

for j=p:length(load)
    if position(j)>position(j+10)
        count2=j;
        break
    end
end

% Truncate end of data
load=load(1:count2);
position=position(1:count2);
displacement = position - load*compliance;

%  Plot truncated data set to compare with original data set
plot(position, load,'k')
hold off
label=[specimen_name '_COMP'];
print ('-dpng', label)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Convert the corrected load/displacement data to stress/strain
if bendtype == '3'
    stress = (load*L*c) / (4*I) * 10^-3;             %MPa
    strain = (12*c*displacement) / (L^2);            %microstrain
end

if bendtype == '4'
   stress = (load*a*c) / (2*I) * 10^-3;             %MPa
   strain = (6*c*displacement) / (a*(3*L - 4*a));   %microstrain
end
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Calculate elastic modulus
k=length(disp_extension);
fit2=polyfit(strain(1:k), stress(1:k),1);
mod=fit2(1);

modulus=mod*10^3; %GPa
 
% Create line with a .2% offset (2000 microstrain)
y_int = -mod*2000;        %y intercept
y_offset = mod*strain + y_int;    %y coordinates of offest line

%Find indeces where the line crosses the x-axis and the stres-strain curve.
%Then truncate offset line between those points
for j = 1 : length(y_offset)
    if y_offset(j) <= 0
        i=j+1;
    end
    if y_offset(j) >= stress(j)
        break
    end
end
x_offset = strain(i:j);
y_offset = y_offset(i:j);
plot(x_offset,y_offset, 'k')

%FAILURE POINT DATA
i = length(load);
fail_load = load(i);
disp_to_fail = displacement(i);
fail_stress = stress(i);
strain_to_fail = strain(i);

%ULTIMATE LOAD POINT DATA
[ultimate_load,i] = max(load);
disp_to_ult = displacement(i);
ultimate_stress = stress(i);
strain_to_ult = strain(i);
ultimate_index = i;

%YIELD POINT DATA
if j > ultimate_index
    j=ultimate_index;
end
yield_load = load(j);
disp_to_yield = displacement(j);
yield_stress = stress(j);
strain_to_yield = strain(j);
yield_index = j;

%Get postyield deformation/strain
postyield_disp = disp_to_fail - disp_to_yield;
postyield_strain = strain_to_fail - strain_to_yield;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if bendtype == '3'
    stiffness = modulus*48*I / (L^3) * 10^3;   % N/mm
end

if bendtype == '4'
   stiffness = modulus*12*I / (a^2 * (3*L -4*a)) * 10^3;   % N/mm
end

%**************************************************************************
%Find pre and post yield energies and toughnesses
%Divide curves up into pre- and post-yield regions. 
strain1 = strain(1:yield_index);
stress1 = stress(1:yield_index);
load1 = load(1:yield_index);
displacement1 = displacement(1:yield_index);

%Calculate areas under curves
preyield_toughness = trapz(strain1,stress1) / 10^6;            % In MPa
total_toughness = trapz(strain,stress) / 10^6;
postyield_toughness = total_toughness - preyield_toughness;

preyield_work = trapz(displacement1,load1) / 10^3;             % In mJ
total_work = trapz(displacement,load) / 10^3;
postyield_work = total_work - preyield_work;

%***********************************************************************
%Plot final graphs of stress/strain
close
figure(3)

%Stress-strain plot
subplot(2,1,1)
plot(strain,stress)
axis xy
xlabel('Strain (microstrain)')
ylabel('Stress (MPa)')
hold on
%plot(linear_strain,linear_stress,'r')
plot(x_offset,y_offset, 'k')
plot(strain_to_yield, yield_stress, 'k+', strain_to_ult, ultimate_stress, 'k+', ...
     strain_to_fail, fail_stress, 'k+')
hold off

%Load-displacement plot
subplot(2,1,2)
plot(displacement,load)
axis xy
xlabel('Displacement (microns)')
ylabel('Force (N)')
hold on
plot(disp_to_yield, yield_load, 'k+', disp_to_ult, ultimate_load, 'k+', ...
     disp_to_fail, fail_load, 'k+')
hold off

%**************************** OUTPUT *********************************************

% Saves an image of figure 3 (summary of mechanical properties)
print ('-dpng', specimen_name) 

% Writes values for mechanical properties to analyze to a xls file with column headers. There
% will be an empty cell afer which outputs for a schematic
% representation of the f/d and stress/strain curves will appear.

resultsxls = {specimen_name, num2str(I), num2str(c), num2str(yield_load), ...
        num2str(ultimate_load), num2str(disp_to_yield), num2str(postyield_disp), num2str(disp_to_fail), ...
        num2str(stiffness), num2str(preyield_work), num2str(postyield_work), ...
        num2str(total_work), num2str(yield_stress), num2str(ultimate_stress), ...
        num2str(strain_to_yield), num2str(strain_to_fail), num2str(modulus),  ...
        num2str(preyield_toughness), num2str(total_toughness), '', specimen_name, ...
        num2str(yield_load), num2str(ultimate_load), num2str(fail_load), ...
        num2str(disp_to_yield), num2str(disp_to_ult), num2str(disp_to_fail), ...
        num2str(yield_stress), num2str(ultimate_stress), num2str(fail_stress), ...
        num2str(strain_to_yield), num2str(strain_to_ult), num2str(strain_to_fail)}; 

    row=num2str(ppp);
    rowcount=['A' row];
    xlswrite(xls, resultsxls, 'Data', rowcount)

ppp=ppp+1;
else
    fprintf('Mechanical data not found for %s.\n',specimen_name)
end
end
fprintf('-----------------ANALSYIS COMPLETE------------------\n')
toc
fprintf('Remember to check output plots!!!\nManually re-run any specimens that looks wrong with Mech_prop_bbml.\n')
end
