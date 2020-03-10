function [links, blocks] = resolvelink(blocks, links, labeldata, p)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% [newlinks, newblocks] = resolvelink(blocks, links, labeldata, p)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% RESOLVELINKS takes top link, and decides whether to combine two objects (which may exist in a set
% of frames). If a link is made, the function modifies remaining blocks, links, and property arrays
% to reflect new object identity.
%
% e.g. object blocks [0 1 0 2 0] and [4 0 0 0 0] could be combined into a single block [4 1 0 2 0]
%
% blocks      array showing linked objects across frames
% links       potentially-linked objects -> [obj1 obj1frame obj2 obj2frame dist delta_area/perim]
%             (or, if provided, last column is replaced with intensity)
% labeldata  structure with centroid,perimeter, and area information
% p           parameters structure
%
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% Find the blocks we're potentially linking.
link = links(1,:);

match1 = find(blocks(:,link(2))==link(1));
if length(match1)>1
    blocks(match1(2:end),link(2)) = 0; % error check: if obj is found multiple times, let earlier obj take precedence
end
match2 = find(blocks(:,link(4))==link(3));
if length(match2)>1
    blocks(match2(2:end),link(4)) = 0;
end
rows = [match1(1), match2(1)];

% Error check: double check that we aren't linking blocks with overlapping frames
if max((blocks(rows(1),:)~=0)+ (blocks(rows(2),:)~=0))>1
    links(1,:) = []; % Drop link
    return;
end


merge_flag = 1;


% If new block has more than 3 objects, ensure that smaller block isn't significantly different from larger 
obj_sums = [sum(blocks(rows(1),:)>0), sum(blocks(rows(2),:)>0)];
if sum(obj_sums) > 3
    if obj_sums(2) >= obj_sums(1)% (rows(1) should refer to largest block)
        rows = rows(end:-1:1);
    end
    frm1 = find(blocks(rows(1),:)>0);
    props1 = zeros(3,length(frm1));
    for i = 1:length(frm1)
        props1(1,i) = labeldata(frm1(i)).area(blocks(rows(1),frm1(i)));
        props1(2,i) = labeldata(frm1(i)).centroidx(blocks(rows(1),frm1(i)));
        props1(3,i) = labeldata(frm1(i)).centroidy(blocks(rows(1),frm1(i)));
    end
    frm2 = find(blocks(rows(2),:)>0);
    props2 = zeros(3,length(frm2));
    for i = 1:length(frm2)
        props2(1,i) = labeldata(frm2(i)).area(blocks(rows(2),frm2(i)));
        props2(2,i) = labeldata(frm2(i)).centroidx(blocks(rows(2),frm2(i)));
        props2(3,i) = labeldata(frm2(i)).centroidy(blocks(rows(2),frm2(i)));
    end
    means1 = mean(props1,2);
    stds1 = std(props1,0,2);
    
    % Check if distance to smaller block is out of range established by larger block
    dist1 = sqrt( ((mean(props2(2,:)) - means1(2)).^2) + ((mean(props2(3,:)) - means1(3)).^2) );
    maxdist = max([5*sqrt(stds1(2)^2 + stds1(3)^2), sqrt(means1(1)/pi)*5]);
    if dist1 > maxdist
        % If 2nd object is single-frame, or also has an out-of range area, invalidate link
        if (mean(props2(1,:)) > (means1(1)+3*stds1(1))) || (mean(props2(1,:)) < (means1(1)+3*stds1(2))) || (length(frm2)==1)
            merge_flag = 0;
        end
    end
end

if p.debug
    disp(['#',num2str(rows(1)),': [',num2str(blocks(rows(1),:)),'] linked to'])
    disp(['#',num2str(rows(2)),': [',num2str(blocks(rows(2),:)),']'])
    disp(['dist: ',num2str(link(5)),', area/perim change: ',num2str(link(6))])
    if ~merge_flag
       disp(['LINK REJECTED- distance ',num2str(dist1), ' vs ' num2str(maxdist)])
    end 
    disp('. . .')
end

if merge_flag % Link accepted - update links and blocks 
    % Make new block, delete old ones
    new_block = blocks(rows(1),:) + blocks(rows(2),:);
    blocks(rows,:) = [];
    blocks = cat(1,blocks,new_block);
    % Drop any link that matches new block
    for col = 1:length(new_block)
        links((links(:,1)==new_block(col)) & (links(:,2)==col),:) = nan;
        links((links(:,3)==new_block(col)) & (links(:,4)==col),:) = nan;
    end
    links(isnan(links(:,1)),:) = [];
    % Re-find links
    new_links = linkblock(new_block, blocks, 1, labeldata, p);

    if ~isempty(new_links)
        links = cat(1,links, new_links);
        % Rank links on distance travelled and morphological (or intensity) similarity
        [~,~,rnk1] = unique(links(:,5));
        [~,~,rnk2] = unique(links(:,6));
        [~,resolve_order] = sort((rnk1*2)+rnk2,'ascend');
        links = links(resolve_order,:);
    end
    
else % Link was rejected, so just delete top link (and its duplicates)
    links((links(:,1)==link(1)) & (links(:,2)==link(2)) & (links(:,3)==link(3)) & (links(:,4)==link(4)),:) = [];
    links((links(:,1)==link(3)) & (links(:,2)==link(4)) & (links(:,3)==link(1)) & (links(:,4)==link(2)),:) = [];
end
