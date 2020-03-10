function [thresh,K,H,bins,testFn] = tsaithresh(image1,dropPixels,bins)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% [thresh,K,H,bins,testFn] = tsaithresh(image1,dropPixels,numBins)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
%  TSAITHRESH Threshold image using method by Tsai (1995)
%
% INPUTS
% image1         image to be thresholded
% dropPixels     binary mask showing pixels to be pulled out of the image
% numBins        bin centers, or number of bins in the histogram function (defaults to 4096)
%
% OUTPUTS
% thresh calculated image threshold, above mode of image
% K      curvature of smoothed histogram
% H      smoothed histogram function
% bins   histogram bins from imagefrom
%
% NOTE: we are dealing with phase images, which are generally unimodal- the
% multimodal part of this algorithm is currently omitted
%
% Tsai, D.M. "A fast thresholding selection procedure 
% for multimodal and unimodal histograms"
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

if nargin<3
    bins = round(numel(image1)/1024);  % Apportion roughly 1000 pixels to a given bin
end
if nargin<2
    dropPixels = false(size(image1));
end


% Get image histogram
image1(dropPixels) = [];
image1 = image1(:);
image1(image1==max(image1)) = [];

% Default parameters, should not need to be changed.
fsize = 3; % Gaussian filter size
R =2; % Radius of curvature, Tsai says <= 3
lowCutoff = 0.02; % sets cutoff for very low peaks

[histFunc, bins] = histcounts(image1,bins);
histFunc = [zeros(size(bins)),histFunc,zeros(size(bins))];


% Make smoothing filter
gaussian = [0.2261 0.5478 0.2261];
gauss = gaussian;
if fsize > 1
    for i = 1:fsize-1
        gauss = conv(gauss,gaussian);
    end
end

% Smooth function, find peaks- Drop all peaks that are less than 2% of max.
 H = ifft(fft(histFunc).*fft(gaussian,length(histFunc)).*conj(fft(gaussian,length(histFunc))));
 [peaks, locs] = findpeaks(H, 'minpeakheight',max(H)*lowCutoff);
 index = 0;


% Continue to smooth til there is only one large peak
 while (length(peaks) > 1) && (index<10)
    H = ifft(fft(H).*fft(gaussian,length(H)).*conj(fft(gaussian,length(H))));
 [peaks locs] = findpeaks(H, 'minpeakheight',max(H)*lowCutoff);
 index = index+1;
 end

 H = H((length(bins)+1):(length(bins)*2));

% ____Unimodal Distribution___________________________________________________
%(maximize rate of change of curvature)
    
% Calculate psi  and K at each point for the histogram function
tCalc = 1+ R*2 : length(H) - R*2; % indices that we're going to check over
psi = zeros(size(H));
K = zeros(size(H));
for  t = tCalc
    for j = 1:R
        psi(t) = psi(t) + (1/R).*(H(t+j) - H(t-j))/(2*j);
    end
end
for  t = tCalc
    for j = 1:R
        K(t) = K(t) + (1/R).*abs(psi(t+j) - psi(t-j));
    end
end


 % Start looking for a maxima after peak H/ peak K value (whichever is farther)
[Kpeaks Klocs]= findpeaks(K);
ind1 = max([find(Kpeaks==max(Kpeaks)), find(Klocs<=find(H==max(H)))]);
Kpeaks_drop = Kpeaks;
Kpeaks_drop(1:ind1) = [ ];
ind2 = find(Kpeaks == Kpeaks_drop(1));
testFn = K(find(K==Kpeaks(ind2-1)):find(K==Kpeaks(ind2)));

% Need to watch out for false positive on the way down from previous peak.
% check: if VALLEY between highest peak and next highest peak is also high,
% find the next highest.
counter = 0;
break_flag = 0;
while (min(testFn) > (Kpeaks_drop(1)/2)) && (counter<3)
    try
        Kpeaks_drop(1) = [];
        ind2 = ind2+1;
        testFn = K(find(K==Kpeaks(ind2-1)):find(K==Kpeaks(ind2)));
        counter = counter+1;
    catch me
        break_flag = 1;
        break
    end
end

if ~break_flag
    thresh = bins(K==Kpeaks_drop(1));
else
    thresh = quickthresh(image1,dropPixels,'none');
end

