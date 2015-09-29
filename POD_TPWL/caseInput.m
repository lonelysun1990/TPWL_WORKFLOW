% caseObj
function [] = caseInput(caseName, caseDir)
caseObj.res_x = 46;
caseObj.res_y = 30;
caseObj.res_z = 1;
caseObj.cen_x = 30;
caseObj.cen_y = 30;
caseObj.cen_z = 1;
caseObj.nComp = 2;

caseObj.dx = 80:160:4720;
caseObj.dy = 80:160:4720;
caseObj.dz = 6.85;
caseObj.temp = 293.15; % K

caseObj.nWell = 2;
caseObj.WBindices = [1121:1:1123,1132:1:1134]';
caseObj.nWellPerf = [3,3];
caseObj.nWellBlock = sum(caseObj.nWellPerf);
caseObj.WIs = 2.9796 * ones(caseObj.nWellBlock, 1);
eval(['save -v7.3 ' caseDir 'data/' caseName '.mat caseObj']);
end