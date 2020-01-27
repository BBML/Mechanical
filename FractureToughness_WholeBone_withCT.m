function FractureToughness_WholeBone_withCT()

%% Revision History

% Edited 1/28/18 by Alycia Berman to use the CTgeom excel output file to
% calculate the structural properties instead of analyzing the cortical
% bitmap images to determine that information (r_outer, r_inner, I_circle).

% Edited 3/8/18 by Katherine Powell to automatically calculate angles (angle_init and angle_inst) with any given centroid or propragation points.

% Edited 1/13/20 by Rachel Kohler to fix CT_geom read-in error, add a loop
% to prevent losing or overwriting data, and some general clean-up.

%% Setup

% Mechanical Test File: 'specimen_number.xls' e.g. 716.xls (OR .ods, .csv)
% SEM File: 'specimen_number_SEM.bmp' e.g. 716_SEM.xls
% CT File: Naming convention doesn't matter, but the specimen number needs
% to be in column 'A', the total cross-sectional area needs to be in column
% 'B', and the marrow area needs to be in column 'C'

%% Code

clear all
close all

zzz=1;
kkk=1;
span=input('Please input the span of the test fixture: ');                  %usually 6 mm
filename2=input('Please input the filename for the output: ','s');          %name of output file
filename2=[filename2 '_MatlabOutput.xls'];
header={'','Span (mm)', '5 Secant (N)', 'Max Force (N)', 'Failure Force (N)', 'Moment of Inertia (mm^4)','angle, initial','angle, instability', 'R_outer', 'R_inner', 'Thickness', 'K, init','K, max load', 'K, inst'};
xlswrite(filename2, header, 1,'A1')                                         %make xls file
[CT_filename, CT_pathname] = uigetfile({'*.xls;*.xlsx;*.csv','Excel Files (*.xls,*.xlsx,*.csv)'; '*.*',  'All Files (*.*)'},'Pick the file with CT info');
CT_Data = xlsread([CT_pathname CT_filename],'Raw Data');
specimen_list=CT_Data(:,1);

for jjj=1:length(specimen_list)
    clearvars -except jjj kkk zzz span CT_Data filename2 Info res filename3 Info2 specimen_list
    close all
    
    specimen=num2str(specimen_list(jjj));
    filename=[specimen '.xls'];
    
    if isfile(filename)
    fprintf('Analyzing %s.\n',specimen)
%     [~,specimen,~]=fileparts(filename);
   
    [P_5secant, P_max, P_final]=Toughness_MechTest(filename);

    [I_circle, r_outer, r_inner]=Toughness_Geom(CT_Data, specimen);
    
    [angle_init, angle_inst]=Toughness_AngleAnalysis(specimen);

    [K_init, K_maxP, K_inst]=Toughness_CalculatingK(span,angle_init,angle_inst, r_outer, r_inner, I_circle, P_5secant, P_max, P_final);

    angle_init=angle_init*180/pi;
    angle_inst=angle_inst*180/pi;
    thickness=r_outer-r_inner;

    Info(kkk,:)=[{filename}, span, P_5secant, P_max, P_final, I_circle, angle_init, angle_inst, r_outer, r_inner, thickness, K_init, K_maxP, K_inst];

% RKK added loop to avoid writing over pre-existing file. This way, if 
% an error happens during a run, the program can be restarted without 
% losing previous work or data.
    zzz=zzz+1;
    row=num2str(zzz);
    cell=['B' row];
    
    % Find first empty row in existing file
    while xlsread(filename2,'Sheet1',cell) ~=0
        zzz=zzz+1;
        row=num2str(zzz);
        cell=['B' row];
    end
    
    % Write data
    row=num2str(zzz);
    rowcount=['A' row];
    xlswrite(filename2, Info, 1, rowcount)
    
    kkk=kkk+1;     
    
    else
        fprintf('Mechanical data not found for %s.\n',specimen)
        continue
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

function [P_5secant, P_max, P_final]=Toughness_MechTest(filename)

disp=-xlsread(filename,'D:D');%N
load=-xlsread(filename,'E:E');%mm

disp(find(isnan(load))) = [];
load(find(isnan(load))) = [];

disp=disp-disp(1);

% disp=smooth(disp,10);
% load=smooth(load,10);

figure
plot(disp, load)
title('Select the start location')
grid on

[startx,~]=ginput(1);
 for x=1:length(disp)
    if disp(x)<=startx
        num1=x;
    end
 end

title('Select the failure location')
[endx,~]=ginput(1);
for x=1:length(disp)
    if disp(x)>=endx
        num2=x;
        break
    end
end

disp(num2:length(disp))=[];
load(num2:length(load))=[];
disp(1:num1)=[];
load(1:num1)=[];

plot(disp,load)
title('Select the initial linear region')

[startx,~]=ginput(1);
 for x=1:length(disp)
    if disp(x)<=startx
        num1=x;
    end
end

[endx,~]=ginput(1);
for x=1:length(disp)
    if disp(x)<=endx
        num2=x;
    end
end

linear_disp=disp(num1:num2);
linear_load=load(num1:num2);

p=polyfit(linear_disp,linear_load,1);

x_shift=-p(2)/p(1);

disp=disp-x_shift;


disp_extension=0:0.01:disp(1);
load_extension=disp_extension.*p(1);

disp=[disp_extension'; disp];
load=[load_extension';load];

plot(disp,load)
title('Select the linear region')

[startx,~]=ginput(1);
 for x=1:length(disp)
    if disp(x)<=startx
        num1=x;
    end
end

[endx,~]=ginput(1);
for x=1:length(disp)
    if disp(x)<=endx
        num2=x;
    end
end

clear linear_disp linear_load

linear_disp=disp(num1:num2);
linear_load=load(num1:num2);

p=polyfit(linear_disp,linear_load,1);

secant5=p(1)*0.95;
secant5load=disp*secant5;

for x=length(disp_extension)+1:length(disp)
    if secant5load(x)<=load(x)
        num3=x;
    end
end

figure
plot(disp, load)
hold on

plot(disp(num3),load(num3),'*m')

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

function [angle_init, angle_inst]=Toughness_AngleAnalysis(specimen)

%For this code to work, the SEM image needs to be rotated such that the
%notch is on the bottom of the screen.

SEMname=[specimen '_SEM.bmp'];
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
