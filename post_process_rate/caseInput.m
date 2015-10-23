% caseObj
function [] = caseInput(caseName, rootDir)
caseObj.res_x = 39;
caseObj.res_y = 39;
caseObj.res_z = 10;
caseObj.cen_x = 25;
caseObj.cen_y = 25;
caseObj.cen_z = 10;
caseObj.nComp = 2;
caseObj.nPhase = 2;

caseObj.dx = 216:436:10684;
caseObj.dy = 216:436:10684;
caseObj.dz = 10;
caseObj.temp = 293.15; % K

caseObj.nWell = 2;
caseObj.WBindices = [10038:1:10040, 11257:1:11259]';
caseObj.nWellPerf = [3,3];
caseObj.nWellBlock = sum(caseObj.nWellPerf);
caseObj.WIs = 14.898 * ones(caseObj.nWellBlock, 1);
eval(['save -v7.3 ' rootDir caseName '/data/' caseName '.mat caseObj']);
end