% Set up camera dynamically

% Get all camera info
%camera_info = imaqhwinfo;

% Get name of last camera attached
%camera_name = char(camera_info.InstalledAdaptors(end));

% Get the info for the last camera attached
%camera_info = imaqhwinfo(camera_name);

% Get the ID of the last camera attached
%camera_id = camera_info.DeviceInfo.DeviceID(end);

% Get the highest supported resolution of the camera
%resolution = char(camera_info.DeviceInfo.SupportedFormats(end));
   
% End dynamic camera setup

% Written for Windows w/ 1 camera, could substitute with:
%vid = videoinput(camera_name, camera_id, resolution);
vid = videoinput('linuxvideo', 1, 'YUYV_960x720');

% Set the properties of the video object
set(vid, 'FramesPerTrigger', Inf);
set(vid, 'ReturnedColorspace', 'rgb');
vid.FrameGrabInterval = 1;

s=serial('/dev/ttyACM0'); 
fopen(s);

start(vid)

while(vid.FramesAcquired <= 250) 
    fprintf(s, '%c', 'q');
    % Get the snapshot of the current frame
    data = getsnapshot(vid);
    
    % Convert to HSV, down-scaling to every 5th vertical line
    diff_im = rgb2hsv(data(1:10:end,:,:));
    
    % Filter the image based on H < 5, S > 40, V > 40 
 
    diff_im = diff_im(:,:,1) < .05 & diff_im(:,:,2) > .4 & diff_im(:,:,3) > .4;
 
    % Remove all connected areas smaller than 300px
    diff_im = bwareaopen(diff_im, 300);
    
    % Get the bounding box and centroid for each labeled region
    stats = regionprops(logical(diff_im), 'Centroid');
    
    % Display the original image
    %imshow(data);
    
    %hold on
    
    % Surround the red objects in a rectangular box and label the centroid
    for object = 1:length(stats)
        %bb = stats(object).BoundingBox;

        % Correct for the down-scaling
        %bb(2) = bb(2) * 5;
        %bb(4) = bb(4) * 5;

        %rectangle('Position',bb,'EdgeColor','r','LineWidth',2)

         %Plot '+' with down-scaling correction
        bc = stats(object).Centroid; 
       % plot(bc(1),bc(2) * 5, '-m+')

       % a=text(bc(1)+15,bc(2) * 5, strcat('X: ', num2str(round(bc(1))), '    Y: ', num2str(round(bc(2)))));
       % set(a, 'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 12, 'Color', 'yellow');
    
        %bc(1)=x-axis
         if bc(1) > 580 %output Right
            dir = 'right' %for display only
            fprintf(s,'%c','d');
         
         elseif bc(1) < 380
             dir = 'left' 
             fprintf(s,'%c','a');
         else 
             dir = 'stop'
             fprintf(s,'%c','q ');
         end
        end    
end
fclose(s);
delete s;
% Close videoinput object
delete(vid)
