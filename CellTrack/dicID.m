function [output, diagnos] =  dicID(image0,p, ~)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% dicID   Classify cell vs background using edge-based method over different scales
%
% image0      original DIC image
% p           parameters struture
%
% output     all masks needed for tracking purposes
% diagnos    major masks/thresholds created as intermediates
%
% Structure: DIC cells are identified using edge informatoion, at multiple scales (of 
% Gaussian filter)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% Subfunctions
% quickthresh.m, noisethresh.m
%
% Notes
% 11/06/2012 - Created, updated CellTrack to include radiobuttons to pick between phase and DIC
% 08/04/2013 - Updated to fit memory checking

% Initial edge transformation on image 
horizontalEdge = imfilter(image0,fspecial('sobel') /8,'symmetric');
verticalEdge = imfilter(image0,fspecial('sobel')'/8,'symmetric');
diagnos.edge_mag = sqrt(horizontalEdge.^2 + verticalEdge.^2);
diagnos.edge_dir = atan(horizontalEdge./verticalEdge);

% Image subset: control for sparsely populated images  
diagnos.subsetThreshold = quickthresh(diagnos.edge_mag,false(size(diagnos.edge_mag)),'none');
diagnos.image_subset = imdilate(diagnos.edge_mag>(diagnos.subsetThreshold), ones(80));

% Edge thresholding: speckle-noise-based  
[diagnos.edgeThreshold, diagnos.noiseCount, diagnos.val] = ...
    noisethresh(diagnos.edge_mag, ~diagnos.image_subset, p.CellSearchRange ,p.NoiseSize);
output.mask0 = diagnos.edge_mag>diagnos.edgeThreshold;
output.mask0 = bwareaopen(output.mask0,p.NoiseSize/4); % Get rid of outlying noise
output.mask0(image0==max(image0(:)))= 1; % Turn on saturated pixels

% Edge thresholding (2): Canny-derived  
diagnos.mask1 = output.mask0;
if ~isempty(diagnos.noiseCount)
    for i = 1:length(p.GaussSizes)
        diagnos.mask1 = cannyalt(image0,p.GaussSizes(i))|diagnos.mask1;
    end
end
diagnos.mask1 = bwareaopen(diagnos.mask1,p.NoiseSize/4,4);

% Eliminate spurious pixels caused by vignetting at camera edge
diagnos.mask1(1:5,:) = imopen(diagnos.mask1(1:5,:),ones(5,1));
diagnos.mask1(end-4:end,:) = imopen(diagnos.mask1(end-4:end,:),ones(5,1));
diagnos.mask1(:,1:5) = imopen(diagnos.mask1(:,1:5),ones(1,5));
diagnos.mask1(:,end-4:end) = imopen(diagnos.mask1(:,end-4:end),ones(1,5));

% "Connection" step: dilate out remaining edges, thin result, then contract if not connected 
diagnos.mask1 = bwareaopen(diagnos.mask1,4);
BWconnect = bwmorph(diagnos.mask1,'skel','Inf');
for i = 3:2:floor(sqrt(p.NoiseSize))
    BWconnect = imdilate(BWconnect,ones(i));
    BWconnect = bwmorph(BWconnect,'skel','Inf');
    % Reduce back result of dilation
    for j = 1:floor(i/2)
        BWendpoints = bwmorph(bwmorph(BWconnect,'endpoints'),'shrink',Inf);
        BWconnect(BWendpoints) = 0;
    end
end
diagnos.mask2 = diagnos.mask1|BWconnect;

%  Eliminate spurious pixels around strong edges 
strong = diagnos.edge_mag>(diagnos.edgeThreshold*5);
strong = bwareaopen(strong,p.NoiseSize*2,4);
diagnos.dnf = imdilate(strong,diskstrel(10)) &~output.mask0;
diagnos.mask2(diagnos.dnf) = 0;

% Hole filling: fill larger holes
holes_mask = bwareaopen(~diagnos.mask2,p.MinHoleSize,4)&~bwareaopen(~diagnos.mask2,p.MaxHoleSize,4);
holes_mask = imclose(holes_mask,ones(3));
holes_cc = bwconncomp(holes_mask,4);
overlapped_obj = 1;
diagnos.fill1 = false(size(holes_mask));
i = 0;
while (~isempty(overlapped_obj)) && (i<10)
    holes_label = labelmatrix(holes_cc);
    holes_test = imdilate(holes_label,diskstrel(5)) - holes_label;
    overlapped_obj = unique(holes_label((holes_mask)&(holes_test~=0)));
    overlapped_obj(overlapped_obj==0) = [];
    
    % Separate label matricies. Dilate the non-overlapped set and determine if they should be filled
    holes_part1 = holes_cc;
    holes_part1.PixelIdxList(overlapped_obj) = [];
    holes_part1.NumObjects = holes_cc.NumObjects-length(overlapped_obj);
    holes_label1 = labelmatrix(holes_part1);
    holes_ring1 = imdilate(holes_label1,ones(3))-holes_label1;
    holes_ring2 = imdilate(holes_label1,diskstrel(5))-holes_label1-holes_label1;
    for i = 1:holes_part1.NumObjects
        a = sum((holes_ring1==i)&diagnos.mask1)/ sum(holes_ring1==i);
        b = sum((holes_ring2==i)&output.mask0)/ sum(holes_ring2==i);
        if (a>0.5) && (b<0.4)
            diagnos.fill1(holes_part1.PixelIdxList{i}) = 1;
        end
    end
    % For overlapped set, re-test.
    holes_cc.PixelIdxList = holes_cc.PixelIdxList(overlapped_obj);
    holes_cc.NumObjects = length(overlapped_obj);
    i = 1+1;
end
diagnos.fill1 = diagnos.fill1 | diagnos.mask2;

% Hole filling: smaller holes
diagnos.fill2 = ~bwareaopen(~diagnos.fill1,p.MinHoleSize,4);
output.mask_cell= imopen(diagnos.fill2,diskstrel(2));

% Save all information under diagnostic struct
diagnos = combinestructures(diagnos,output);