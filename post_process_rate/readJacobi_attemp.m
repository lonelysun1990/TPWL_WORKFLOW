% read the Jacobi matrix at each time step
function [] = readJacobi_attemp(caseName, schedule, caseDir, iCase)

ijacbDir = [caseDir 'training_' int2str(iCase) '/'];% directory to input jacobian
ioDir = [caseDir 'data/'];

fprintf(['loading Jacobian for schedule ',int2str(schedule),':\n']);
eval(['load ' ioDir 'stateVariable_' int2str(schedule) '.mat timeStep time']);
eval(['load ' ioDir caseName '.mat']);
nCell = caseObj.res_x * caseObj.res_y * caseObj.res_z;
nComp = caseObj.nComp;
nWell = caseObj.nWell;
% read derivatives from binary files
J = loadJ(ijacbDir, nCell, nComp, timeStep);
Acc = loadA(ijacbDir, nCell, nComp, timeStep, time);
dQdu =loadU(ijacbDir, nCell, nComp, nWell, timeStep);
% save derivatives to .mat files
eval(['save -v7.3 ' ioDir 'Matrix_U_' int2str(schedule) ' dQdu;']); % used to be trainingData110.mat
eval(['save -v7.3 ' ioDir 'Matrix_J_' int2str(schedule) ' J;']);
eval(['save -v7.3 ' ioDir 'Matrix_Acc_' int2str(schedule) ' Acc;']);
end

function [J] = loadJ(iputDir, nCell, nComp, timeStep)
% Load J (stroed as compressed sparse row matrix in binary file)
J = cell(timeStep, 1);
for i = 1 : timeStep
    fid = fopen([ iputDir 'J_step_' int2str(i-1) '.dat']);
    nElem = fread(fid, 1, 'int');
    nRow = fread(fid, 1, 'int');
    col = fread(fid, nElem, 'int') + 1;
    row = [0; fread(fid, nRow, 'int')] + 1;
    val = fread(fid, nElem, 'double');
    fclose(fid);
    
    [nzi, nzj, nzv] = csr_to_sparse(row, col, val, nRow);
    tempJ = spconvert([nzi, nzj, nzv]);% convert into sparse matrix
    if min(size(tempJ)) < nCell * nComp
        tempJ(nCell * nComp, nCell * nComp) = 0;
    end
    if max(size(tempJ)) > nCell * nComp
        tempJ = tempJ(1:nCell * nComp, 1:nCell * nComp);
    end
    J(i) = {tempJ};
end
end

function [Acc] = loadA(iputDir, nCell, nComp, timeStep, time)
% Load Acc (stored as sparse matrix in binary file)
dt = diff(time);
Acc = cell(timeStep, 1);
for i = 1 : timeStep
    if i == 1
        fid = fopen([iputDir 'A_step_' int2str(1) '.dat']);
    else
        fid = fopen([iputDir 'A_step_' int2str(i-1) '.dat']);
    end
    nElem = fread(fid, 1, 'int');
    col = fread(fid, nElem, 'int');
    row = fread(fid, nElem, 'int');
    val = fread(fid, nElem, 'double');
    fclose(fid);
    
    D = [row+1, col+1, val];
    tempAcc = spconvert([D; nCell * nComp, nCell * nComp, 0]);% convert into sparse matrix
%     if i > 1
%         tempAcc = tempAcc * dt(i-1) / dt(i);% correct Ai+1 to Bi+1
%     end
    Acc(i) = {tempAcc};
end
end

function [dQdu] =loadU(iputDir, nCell, nComp, nWell, timeStep)
% Load dQdu
dQdu = cell(timeStep, 1);
for i = 1 : timeStep
    temp = dlmread([iputDir 'U_step_' int2str(i-1) '.dat']);
    D = [temp(:,1)+1, temp(:,2)+1, temp(:,3)];
    tempU = spconvert([D; nCell * nComp, nWell, 0]);% convert into sparse matrix
    if size(tempU, 1) > nCell * nComp
        tempU = tempU(1:nCell * nComp, :);
    end
    dQdu(i) = {tempU};
end
end

function [nzi,nzj,nzv] = csr_to_sparse(rp,ci,ai,ncols)
% CSR_TO_SPARSE Convert from compressed row arrays to a sparse matrix
%
% A = csr_to_sparse(rp,ci,ai) returns the sparse matrix represented by the
% compressed sparse row representation rp, ci, and ai.  The number of
% columns of the output sparse matrix is max(max(ci),nrows).  See the call
% below.
%
% A = csr_to_sparse(rp,ci,ai,ncol) While we can infer the number of rows 
% in the matrix from this expression, you may want a
% different number of 
%
% [nzi,nzj,nzv] = csr_to_sparse(...) returns the arrays that feed the
% sparse call in matlab.  You can use this to avoid the sparse call and
% customize the behavior.
%
% This command "inverts" the behavior of sparse_to_csr.
% Repeated entries in the matrix are summed, just like sparse does.  
%
% See also SPARSE SPARSE_TO_CSR
% 
% Example:
%   A=sparse(6,6); A(1,1)=5; A(1,5)=2; A(2,3)=-1; A(4,1)=1; A(5,6)=1; 
%   [rp ci ai]=sparse_to_csr(A); 
%   A2 = csr_to_sparse(rp,ci,ai)
%
% David F. Gleich
% Copyright, Stanford University, 2008-2009
%
%  History
%  2009-05-01: Initial version
%  2009-05-16: Documentation and example

nrows = length(rp)-1;
nzi = zeros(length(ci),1);
for i=1:nrows
    for j=rp(i):rp(i+1)-1
        nzi(j) = i;
    end
end

if nargout<2,
    if nargin>3,
        nzi = sparse(nzi,ci,ai,nrows,ncols);
    else
        % we make the matrix square unless there are more columns
        ncols = max(max(ci),nrows);
        if isempty(ncols), ncols=0; end
        nzi = sparse(nzi,ci,ai,nrows,ncols);
    end
else
    nzj = ci;
    nzv = ai;
end 
end
