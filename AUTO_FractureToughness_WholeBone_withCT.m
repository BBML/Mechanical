function AUTO_FractureToughness_WholeBone_withCT()

%% Revision History

% Edited 1/28/18 by Alycia Berman to use the CTgeom excel output file to
% calculate the structural properties instead of analyzing the cortical
% bitmap images to determine that information (r_outer, r_inner, I_circle).

% Edited 3/8/18 by Katherine Powell to automatically calculate angles (angle_init and angle_inst) with any given centroid or propragation points.

% Edited 1/13/20 by Rachel Kohler to fix CT_geom read-in error, add a loop
% to prevent losing or overwriting data, and some general clean-up.

% Edited 1/28/20 by Rachel Kohler to automate the mechanical point-picking.

%% Setup

% Mechanical Test File: 'specimen_number.xls' e.g. 716.xls (OR .ods, .csv)
% SEM File: 'specimen_number_SEM.bmp' e.g. 716_SEM.xls
% CT File: Naming convention doesn't matter, but the specimen number needs
% to be in column 'A', the total cross-sectional area needs to be in column
% 'B', and the marrow area needs to be in column 'C'

%% Code

clear all
close all

span=input('Please input the span of the test fixture: ');                  %usually 7.5 mm
filename2=input('Please input the filename for the output: ','s');          %name of output file

% Creating output file
filename2=[filename2 '_MatlabOutput.xls'];
header={'','Span (mm)', '5 Secant (N)', 'Max Force (N)', 'Failure Force (N)', 'Moment of Inertia (mm^4)','angle, initial','angle, instability', 'R_outer', 'R_inner', 'Thickness', 'K, init','K, max load', 'K, inst'};
xlswrite(filename2, header, 1,'A1')                                         %make xls file

% Getting CT Data
[CT_filename, CT_pathname] = uigetfile({'*.xls;*.xlsx;*.csv','Excel Files (*.xls,*.xlsx,*.csv)'; '*.*',  'All Files (*.*)'},'Pick the file with CT info');
CT_Data = xlsread([CT_pathname CT_filename],'Raw Data');
specimen_list=CT_Data(:,1);

% Loop through specimen numbers listed in CT_Data file
for jjj=1:length(specimen_list)
    
    clearvars -except jjj span CT_Data filename2 res filename3 Info2 specimen_list
    close all
    
    specimen=num2str(specimen_list(jjj));
    
    % Check if specimen has already been run
    zzz=2;
    row=num2str(zzz);
    cell=['A' row];
    
    while xlsread(filename2,'Sheet1',cell) ~=0
        if xlsread(filename2,'Sheet1',cell)==str2num(specimen)
            break
        end
        zzz=zzz+1;
        row=num2str(zzz);
        cell=['A' row];
    end

    if xlsread(filename2,'Sheet1',cell)==str2num(specimen)
        fprintf('%s has already been analyzed. Moving to next specimen.\n',specimen)
        continue
    end
    
    filename=[specimen '.xls'];
    SEMname=[specimen '_SEM.bmp'];
    
    % Check if mechanical and SEM files are both present
    if isfile(filename) && isfile(SEMname)
    fprintf('Analyzing %s.\n',specimen)
    
    % Run through these functions, detailed below
    [P_5secant, P_max, P_final]=Toughness_MechTest(filename,specimen);

    [I_circle, r_outer, r_inner]=Toughness_Geom(CT_Data, specimen);
    
    [angle_init, angle_inst]=Toughness_AngleAnalysis(SEMname, specimen);

    [K_init, K_maxP, K_inst]=Toughness_CalculatingK(span,angle_init,angle_inst, r_outer, r_inner, I_circle, P_5secant, P_max, P_final);

    % Calculate and print final outputs
    angle_init=angle_init*180/pi;
    angle_inst=angle_inst*180/pi;
    thickness=r_outer-r_inner;

    Info=[{specimen}, span, P_5secant, P_max, P_final, I_circle, angle_init, angle_inst, r_outer, r_inner, thickness, K_init, K_maxP, K_inst];

    % Write data
    xlswrite(filename2, Info, 1, cell)
    
    elseif isfile(SEMname)
        fprintf('Mechanical data not found for %s.\n',specimen)
    else
        fprintf('SEM file not found for %s.\n',specimen)
    end
end
close all
end

function [K_init, K_maxP, K_inst]=Toughness_CalculatingK(s,angle_init,angle_inst, r_outer, r_inner, I, P_5secant, P_max, P_final)

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

K_init=Fb*((P_5secant*s*r_outer)/(4*I))*((pi*rm*angle_init)^0.5);

K_maxP=Fb*((P_max*s*r_outer)/(4*I))*((pi*rm*angle_init)^0.5);

v=angle_inst/pi;

Fb=(1+(t/(2*rm)))*(Ab+Bb*v+Cb*v^2+Db*v^3+Eb*v^4);

K_inst=Fb*((P_final*s*r_outer)/(4*I))*((pi*rm*angle_inst)^0.5);

end

function [P_5secant, P_max, P_final]=Toughness_MechTest(filename,specimen)

position=-xlsread(filename,'D:D')*10^3;%microns
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
plot(disp, load,'k')
hold on

% Calculate values
secant5=slope*0.95;
secant5load=disp*secant5;

for x=length(disp_extension)+1:length(disp)
    if secant5load(x)<=load(x)
        num3=x;
    end
end

%if exist('num3','var')
%else
%    num3=1;
%end
    
plot(disp(num3),load(num3),'*m')
hold off
label=[specimen '_COMP'];
print ('-dpng', label);

P_5secant=load(num3);
P_max=max(load);
P_final=load(length(load));

end

function [I_circle, r_outer, r_inner]=Toughness_Geom(CT_Data, specimen)

% Get CT Data
CT_Data_Row = find(CT_Data(:,1)==str2num(specimen));
tCSA = CT_Data(CT_Data_Row,2); %mm^2
MA = CT_Data(CT_Data_Row,3); %mm^2

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
print ('-dpng', specimen)

end
