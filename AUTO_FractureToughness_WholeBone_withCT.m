function AUTO_FractureToughness_WholeBone_withCT()

%% Revision History

% Edited 1/28/18 by Alycia Berman to use the CTgeom excel output file to
% calculate the structural properties instead of analyzing the cortical
% bitmap images to determine that information (r_outer, r_inner, I_circle).

% Edited 3/8/18 by Katherine Powell to automatically calculate angles (angle_init and angle_inst) with any given centroid or propragation points.

% Edited 1/13/20 by Rachel Kohler to fix CT_geom read-in error, add a loop
% to prevent losing or overwriting data, and some general clean-up.

% Edited 1/28/20 by Rachel Kohler to automate the mechanical point-picking.

% Edited 4/20 by Rachel Kohler to add extra do-dadds such as changing
% input method, checking if a specimen has already been analyzed, adding 
% compatibility for alpha-numeric specimen names, and creating subfolders
% of output plots.
% Further, the method of calculating yield load was changed from using the
% secant method to the 0.2% offset method, due to issues with accuracy.

%% Setup

% Mechanical Test File: 'specimen_number.xls' e.g. 716.xls (OR .ods, .csv)
% SEM File: 'specimen_number_SEM.bmp' e.g. 716_SEM.bmp
% CT File: Naming convention doesn't matter, but the specimen number needs
% to be in column 'A', the total cross-sectional area needs to be in column
% 'B', and the marrow area needs to be in column 'C'

%% Code
%*****************\TESTING CONFIGURATION/**********************************
%                                                                         *
%   Adjust these values to match the system setup.                        *
%                                                                         *
span = 7.50;           %span between bottom load points (mm)              *
compliance = 0;     %system compliance (microns/N)                        *
side = 'L';         %input 'R' for right and 'L' for left                 *
bone = 'T';         %enter 'F' for femur and 'T' for tibia                *
filename2 = 'Amish16wk_';    %enter study label for output excel sheet (eg 'STZ_')*
%**************************************************************************

%Check common errors in testing configuration
if strcmp(side,'L') == 0 && strcmp(side,'R') == 0
        error('Please enter R or L for side as a string in the Testing Configuration')
end

if bone ~= 'F' && bone ~= 'T'
        error('Please F or T for bone as a string in the Testing Configuration')
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
        disp([answer ' See line 29 in the code. Please edit testing configuration values.'])
        return
end

% Predefine variables and create output file
xls=[filename2 'FXoutput.xls'];

% span=input('Please input the span of the test fixture: ');                  %usually 6 mm
% filename2=input('Please input the filename for the output: ','s');          %name of output file
% filename2=[filename2 '_FXoutput.xls'];
header={'','Span (mm)', 'Yield Force (N)', 'Max Force (N)', 'Failure Force (N)', 'Moment of Inertia (mm^4)','angle, initial','angle, instability', 'R_outer', 'R_inner', 'Thickness', 'K, init','K, max load', 'K, inst'};
xlswrite(xls, header, 1,'A1')                                         %make xls file

% Make folders for output images
mkdir('Before-After Comp')
mkdir('Stress-Strain Plots')
mkdir('SEM Points')

[CT_filename, CT_pathname] = uigetfile({'*.xls;*.xlsx;*.csv','Excel Files (*.xls,*.xlsx,*.csv)'; '*.*',  'All Files (*.*)'},'Pick the file with CT info');
[~,~,CT_Data] = xlsread([CT_pathname CT_filename],'Raw Data');
specimen_list=CT_Data(2:end,1);

zzz=1;

for jjj=1:length(specimen_list)
    clearvars -except xls b jjj zzz bone span CT_Data filename2 Info res filename3 Info2 specimen_list
    close all
    
    specimen=specimen_list{jjj};
    ppp=jjj+1;
    
    if isnumeric(specimen)
        specimen=num2str(specimen);
    end

    filename=[specimen '.xls'];
    SEMname=[specimen '_SEM.bmp'];
    
    if isfile(filename) && isfile(SEMname)
   
    % Find first empty row in output file
    zzz=zzz+1;
    row=num2str(zzz);
    cell=['A' row];
    b=0;
    
    while xlsread(xls,1,cell) ~=0
        % Check if the specimen has already been analyzed
        if xlsread(xls,1,cell)==str2num(specimen)
            b=1;
            break
        else
            zzz=zzz+1;
            row=num2str(zzz);
            cell=['A' row];
        end
    end
    
    % Option to redo a previously analyzed specimen or continue to next
    if b==1
        b=0;
        answer = questdlg(sprintf('%s has already been processed. Would you like to redo %s?',specimen), ...
            'Sanity Check', ...
            'Yes','No','No');
        % Handle response
        switch answer
            case 'Yes'
            case 'No'
                continue
        end
    end
    
    % Start analysis
    fprintf('Analyzing %s.\n',specimen)
   
    [P_yield, P_max, P_final]=Toughness_MechTest(filename,specimen,ppp,span,bone,CT_Data);

    [I_circle, r_outer, r_inner]=Toughness_Geom(CT_Data, ppp);
    
    [angle_init, angle_inst]=Toughness_AngleAnalysis(SEMname, specimen);

    [K_init, K_maxP, K_inst]=Toughness_CalculatingK(span,angle_init,angle_inst, r_outer, r_inner, I_circle, P_yield, P_max, P_final);

    angle_init=angle_init*180/pi;
    angle_inst=angle_inst*180/pi;
    thickness=r_outer-r_inner;

    Info=[{specimen}, span, P_yield, P_max, P_final, I_circle, angle_init, angle_inst, r_outer, r_inner, thickness, K_init, K_maxP, K_inst];
    
    % Write data
    rowcount=['A' row];
    xlswrite(xls, Info, 1, rowcount)   
    
    elseif isfile(SEMname)
        fprintf('Mechanical data not found for %s.\n',specimen)
        continue
    else
        fprintf('SEM image not found for %s.\n',specimen)
    end
end
fprintf('----------------- ANALYSIS COMPLETE ------------------\n')
close all
end

function [K_init, K_maxP, K_inst]=Toughness_CalculatingK(s,angle_init,angle_inst, r_outer, r_inner, I, P_yield, P_max, P_final)

angle_init=angle_init/2;
angle_inst=angle_inst/2;

rm=(r_outer+r_inner)/2;%mm
rm=rm/1000;%m
t=r_outer-r_inner;%mm
t=t/1000;%m
v=angle_init/pi;
e=log10(t/rm);

Ab=0.65133-0.5774*e-0.3427*e^2-0.0681*e^3;
Bb=1.879+4.795*e+2.343*e^2-0.6197*e^3;
Cb=-9.779-38.14*e-6.611*e^2+3.972*e^3;
Db=34.56+129.9*e+50.55*e^2+3.374*e^3;
Eb=-30.82-147.6*e-78.38*e^2-15.54*e^3;
Fb=(1+(t/(2*rm)))*(Ab+Bb*v+Cb*v^2+Db*v^3+Eb*v^4);

K_init=Fb*((P_yield*s*r_outer)/(4*I))*((pi*rm*angle_init)^0.5);

K_maxP=Fb*((P_max*s*r_outer)/(4*I))*((pi*rm*angle_init)^0.5);

v=angle_inst/pi;

Fb=(1+(t/(2*rm)))*(Ab+Bb*v+Cb*v^2+Db*v^3+Eb*v^4);

K_inst=Fb*((P_final*s*r_outer)/(4*I))*((pi*rm*angle_inst)^0.5);

end

function [P_yield, P_max, P_final]=Toughness_MechTest(filename,specimen,ppp,span,bone,CT_Data)

position=xlsread(filename,'D:D')*10^3;%microns
load=-xlsread(filename,'E:E');%N

position(find(isnan(load))) = [];
load(find(isnan(load))) = [];
disp=linspace(0,position(end),length(load))';

figure()
plot(disp,load)
hold on

% Find elastic modulus ---------------------------------------------------
ultimate_load= max(load);
i=50;
j=100;
y=load(1:i);
x=disp(1:i);

while y<ultimate_load 
    fit=polyfit(x,y,1);
    slope1(i)=fit(1);
    % Go to next set of points
    y=load(i:j);
    x=disp(i:j);
    i=i+10;
    j=j+10;
end

% Select the top 30 slope values and average them. 
slope2=slope1;

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

% Truncate data
load=load(count1:end);
disp=disp(count1:end);

% Extrapolate out missing info
load_extension(1)=0;
disp_extension(1)=0;
i=1;

while load_extension(i)<load(1)
    i=i+1;
    disp_extension(i)=i-1;
    load_extension(i)=disp_extension(i)*slope;
end
disp=disp+disp_extension(end)-disp(1);
disp=[disp_extension'; disp];
load=[load_extension';load];

% Find failure point -----------------------------------------------------
[ultimate_load, n] = max(load);

for i=n:length(load)
    if load(i)<1 && max(load(i:end))<1
        count2=i-5;
    break
    else
        count2=i;
    end
end

% Truncate Data
load=load(1:count2);
disp=disp(1:count2);

%  Plot truncated data set to compare with original data set
cd('Before-After Comp')
plot(disp, load,'k')
hold off
label=[specimen '_COMP'];
print ('-dpng', label);
cd('..')

% Calculate stress/strain plot
if bone == 'F'
    I =   CT_Data{ppp,16}; %I_ml         
    c =   CT_Data{ppp,19}*1000; %c_ant
    
elseif bone == 'T'
    I =   CT_Data{ppp,8}; %I_ap          
    c =   CT_Data{ppp,12}*1000; %c_med
end

stress = (load*span*c) / (4*I) * 10^-3;             %MPa
strain = (12*c*disp) / (span^2); 

% Calculate elastic modulus
k=length(disp_extension);
fit2=polyfit(strain(1:k), stress(1:k),1);
mod=fit2(1);

modulus=mod*10^3; %GPa
 
% Create line with a .2% offset (2000 microstrain)
y_int = -mod*20000;        %y intercept
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

%YIELD POINT DATA
[P_max,i] = max(load);
if j > i
    j=i;
end
P_yield = load(j);
yield_stress = stress(j);
strain_to_yield = strain(j);
yield_index = j;
P_final=load(length(load));

% Save output plot
cd('Stress-Strain Plots')

figure()
plot(strain,stress)
hold on
plot(x_offset,y_offset, 'k')
plot(strain_to_yield, yield_stress, 'k+')
xlabel('Strain (\mu\epsilon)')
ylabel('Stress (MPa)')
legend('Stress-Strain Curve', '0.2% Off-set','Yield Point','location','southeast')
print ('-dpng', specimen);
cd('..')
end

function [I_circle, r_outer, r_inner]=Toughness_Geom(CT_Data, ppp)

% Get CT Data
tCSA = CT_Data{ppp,2}; %mm^2
MA = CT_Data{ppp,3}; %mm^2

r_outer = sqrt(tCSA/pi); %mm
r_inner = sqrt(MA/pi); %mm

I_circle = (pi/4)*(r_outer.^4 - r_inner.^4); %mm^4

end

function [angle_init, angle_inst]=Toughness_AngleAnalysis(SEMname, specimen)

%For this code to work, the SEM image needs to be rotated such that the
%notch is on the bottom of the screen.
image1=imread(SEMname); 

figure
imshow(image1)
title('Please click on the centroid.')
[xbar,ybar]=ginput(1);

title('Please click on the two notch edges.')
[x_init1,y_init1]=ginput(1);
[x_init2,y_init2]=ginput(1);

if x_init1>x_init2
    temp=x_init1;
    x_init1=x_init2;
    x_init2=temp;
    temp=y_init1;
    y_init1=y_init2;
    y_init2=temp;
end

%initial notch angle
%identify location of 1st point
if (y_init1 - ybar) < 0                                                     %if point is above centroid
    angle_init1=atan((abs(y_init1-ybar))/(abs(x_init1-xbar))) + pi/2;       %add 90 degrees to angle
else
    angle_init1=atan((abs(x_init1-xbar))/(abs(y_init1-ybar)));
end

%identify location of 2nd point
if (y_init2 - ybar) < 0                                                    %if point is above centroid
    angle_init2=atan((abs(y_init2-ybar))/(abs(x_init2-xbar))) + pi/2;       %add 90 degrees to angle
else
    angle_init2=atan((abs(x_init2-xbar))/(abs(y_init2-ybar)));
end

angle_init=angle_init1+angle_init2;

%I am not for sure what this code does - KP
while angle_init<0
    angle_init=angle_init+(2*pi);
end

while angle_init>(2*pi)
    angle_init=angle_init-(2*pi);
end

%select instability edge
title('Please click on the two instability edges.')
[x_inst1,y_inst1]=ginput(1);
[x_inst2,y_inst2]=ginput(1);


angle_inst1=atan((abs(x_inst1-xbar))/(abs(y_inst1-ybar)));
angle_inst2=atan((abs(x_inst2-xbar))/(abs(y_inst2-ybar)));

if x_inst1>x_inst2
    temp=x_inst1;
    x_inst1=x_inst2;
    x_inst2=temp;
    temp=y_inst1;
    y_inst1=y_inst2;
    y_inst2=temp;
end

%instability angle
%identify location of 1st point
if (y_inst1 - ybar) < 0                                                     %if point is above centroid
    angle_inst1=atan((abs(y_inst1-ybar))/(abs(x_inst1-xbar))) + pi/2;       %add 90 degrees to angle
else
    angle_inst1=atan((abs(x_inst1-xbar))/(abs(y_inst1-ybar)));
end

%identify location of 2nd point
if (y_inst2 - ybar) < 0                                                    %if point is above centroid
    angle_inst2=atan((abs(y_inst2-ybar))/(abs(x_inst2-xbar))) + pi/2;       %add 90 degrees to angle
else
    angle_inst2=atan((abs(x_inst2-xbar))/(abs(y_inst2-ybar)));
end

angle_inst=angle_inst1+angle_inst2;

while angle_inst<0
    angle_inst=angle_inst+(2*pi);
end

while angle_inst>(2*pi)
    angle_inst=angle_inst-(2*pi);
end


imshow(image1)
hold on
plot(xbar,ybar,'*c');
plot(x_init1,y_init1,'*b');
plot(x_init2,y_init2,'*b');
plot(x_inst1,y_inst1,'*b');
plot(x_inst2,y_inst2,'*b');

% Save last figure as an image
cd('SEM Points')
print ('-dpng', specimen)
cd('..')
end