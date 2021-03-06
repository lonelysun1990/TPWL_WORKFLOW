% attemp to reduce the model through SVD
function [] = POD_attemp(caseDir, caseName, trainingSchedule)
% trainingSchedule = [500,510]
ioDir = [caseDir 'data/'];
eval(['load ' ioDir caseName '.mat']);
model = 1;% compositional model
nComp = caseObj.nComp;
nCell = caseObj.res_x * caseObj.res_y * caseObj.res_z;
% combine state variables from snapshots
[stateUnion] = loadStateVariable(ioDir, trainingSchedule, nComp, nCell);
% SVD variable by varible P, C1, C2, ...
[phi, phiT] = svdDecomp(stateUnion, nComp);
rBasis = basisReduce(ioDir, trainingSchedule, phiT, nCell, nComp);
[Jr, Accr, dQdur] = derivReduce(ioDir, trainingSchedule, phi, ...
    nCell, nComp, 'PG');
eval(['save -v7.3 ' ioDir 'reducedInfo_' int2str(trainingSchedule(1)) ' Jr Accr dQdur phi phiT rBasis']);
end

function [stateUnion] = loadStateVariable(ioDir, trainingSchedule, nComp, nCell)
stateUnion = [];
for iTrain = trainingSchedule
    eval(['load ' ioDir 'stateVariable_' int2str(iTrain) ' snapShots timeStep']);
    tempState = reshape(snapShots', timeStep + 1, nComp, nCell);
    stateUnion = cat(1, stateUnion, tempState);
end
stateUnion = permute(stateUnion, [3,1,2]);
end

function [phi, phiT] = svdDecomp(stateUnion, nComp)
nSnap = size(stateUnion, 2);
nCell = size(stateUnion, 1);
pUnion = stateUnion(:,:,1); % get pressure snapshots
stateUnion(:,:,1) = [];
stateUnion = permute(stateUnion, [1,3,2]);
compUnion = reshape(stateUnion, nCell*(nComp - 1), nSnap);
[U_p, S_p] = svd(pUnion/sqrt(nSnap),0);
nBasis_p = energyCriteria(1, S_p);
phiP = U_p(:,1:nBasis_p);
[U_comp, S_comp] = svd(compUnion/sqrt(nSnap),0);
nBasis_comp = energyCriteria(2, S_comp);
phiComp = U_comp(:,1:nBasis_comp);
% Modification on Jan. 16, 2015
phi = zeros(nCell*nComp, nBasis_p + nBasis_comp);
phi(1:nComp:end-nComp+1, 1:nBasis_p) = phiP;
for iComp = 1: nComp -1 
    phi(iComp+1:nComp:end-nComp+iComp+1, nBasis_p + 1:nBasis_p + nBasis_comp) = phiComp(nCell*(iComp-1)+1:nCell*iComp,:);
%     phi(3:nComp:end, nBasis_p + 1:nBasis_p + nBasis_comp) = phiComp(nCell+1:2*nCell,:);
end
phiT = phi';
end

function [nBasis] = energyCriteria(iComp, S, basisInds)
lpls_dirty = [37; 37; 37];
nBasis = lpls_dirty(iComp);
%     lambda = diag(S);
%     energy = cumsum(lambda)/sum(lambda); % energy criteria, not used right now
%     energyPo =0.9999985;     
%     temp = find(energy > energyPo);
%     nBasis = temp(1);
end

function [rBasis] = basisReduce(ioDir, trainingSchedule, phiT, nCell, nComp)
eval(['load ' ioDir 'stateVariable_' int2str(trainingSchedule(1)) '.mat snapShots timeStep']);
% tempState = reshape(snapShots', timeStep + 1, nComp, nCell);
% statePermute = permute(tempState, [3, 2, 1]);
% fullBasis = reshape(statePermute, nCell * nComp, timeStep + 1);
fullBasis = snapShots;
rBasis = phiT * fullBasis;
end

function [Jr, Accr, dQdur] = derivReduce(ioDir, trainingSchedule, phi, ...
    nCell, nComp, projM)
if nargin < 4, projM = 'PG'; end % set Petrov-Galerkin as default
eval(['load ' ioDir 'Matrix_Acc_' int2str(trainingSchedule(1)) '.mat Acc']);
eval(['load ' ioDir 'Matrix_J_' int2str(trainingSchedule(1)) '.mat J']);
eval(['load ' ioDir 'Matrix_U_' int2str(trainingSchedule(1)) '.mat dQdu']);
% different projection method
if strcmp(projM, 'PG')
    [Jr, Accr, dQdur] = projPG(phi, J, Acc, dQdu, nCell, nComp);
elseif strcmp(projM, 'GLK')
    % wait to be implemented
%     [Jr, Accr, dQdur] = projGLK(phi, J, Acc, dQdu);
end  
end

function [Jr, Accr, dQdur] = projPG(phi, J, Acc, dQdu, nCell, nComp)
% Petrov-Galerkin Projection
timeStep = size(J, 1);
scaleEq = speye(nComp*nCell);
Jr = cell(timeStep, 1);
Accr = cell(timeStep, 1);
dQdur = cell(timeStep, 1);
for iStep =1:timeStep
%     psi = J{iStep} * scaleEq * phi;
%     psiT = psi';
%     Jr(iStep) = {psiT * psi};
%     Accr(iStep) = {psiT * (scaleEq * Acc{iStep} * phi)};
%     dQdur(iStep) = {psiT * (scaleEq * dQdu{iStep})};
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    psiT = (J{iStep} * scaleEq * phi)';
%     psi = psiT';
    Jr(iStep) = {psiT * psiT'};
    Accr(iStep) = {psiT * (scaleEq * Acc{iStep} * phi)};
    dQdur(iStep) = {psiT * (scaleEq * dQdu{iStep})};
end
end

function [Jr, Accr, dQdur] = projGLK(phi, J, Acc, dQdu)
% Galerkin Projection
end