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
vid.FrameGrabInterval = 2;

s=serial('/dev/ttyACM0'); 
fopen(s);

%preview(vid)
start(vid);

% Get 25 frames then stop and clean up
%
% Note:
%
% If this loop doesn't complete correctly, the camera object will not be 
% cleaned up properly and you'll have to restart Matlab to get it to run again!!
cnt = 0;
tic;
while(cnt < 25)%vid.FramesAcquired <= 200) 
   cnt = cnt + 1;
   fwrite(s, 'q');
   % Get the snapshot of the current frame
   try
      data = getsnapshot(vid);
   end

   % Convert to HSV, down-scaling to every 5th vertical line
   diff_im = rgb2hsv(data(1:5:end,:,:));
   
   % Filter the image based on H < 5, S > 40, V > 40 (the red color of my
   % keychain CPR mask  :P
   diff_im = diff_im(:,:,1) < .05 & diff_im(:,:,2) > .4 & diff_im(:,:,3) > .4;

   % Remove all connected areas smaller than 300px
   diff_im = bwareaopen(diff_im, 300);

   % Get the bounding box and centroid for each labeled region
   stats = regionprops(logical(diff_im), 'Centroid');

   % Display the original image
   %imshow(data)
   %hold on

   n = length(stats);

   if(n == 0)
      dir = 'none';
      disp(dir);
      fwrite(s, 'q');
   else
   % Surround the red objects in a rectangular box and label the centroid
      for object = 1:length(stats)
         %bb = stats(object).BoundingBox;

         % Correct for the down-scaling
         %bb(2) = bb(2) * 5;
         %bb(4) = bb(4) * 5;

         %rectangle('Position',bb,'EdgeColor','r','LineWidth',2)

         % Plot '+' with down-scaling correction
         bc = stats(object).Centroid; 
         %plot(bc(1),bc(2) * 5, '-m+')

         %a=text(bc(1)+15,bc(2) * 5, strcat('X: ', num2str(round(bc(1))), '    Y: ', num2str(round(bc(2)))));
         %set(a, 'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 12, 'Color', 'yellow');

         %bc(1)=x-axis
         if bc(1) > 730 %output Right
            dir = 'right';
            disp(dir);         
            fwrite(s,'d');
         elseif bc(1) < 230;
            dir = 'left';
            disp(dir)
            fwrite(s,'a');
         else 
            dir = 'stop';
            disp(dir);
            fwrite(s,'q');
         end

%         area = stats(object).Area;
%         disp(area);
%         if area < 700
%            dir_fb = 'foward'; %  output Fwd
%            fwrite(s,'w');
%         elseif area > 700 & cd < 1000 % output stop
%            dir_fb = 'stop';
%            fwrite(s,'q');
%         else area > 1000 %  output reverse
%            dir_fb = 'reverse';
%            fwrite(s,'s');
%         end
      end
   end    
end
toc;

fwrite(s, 'q');

fclose(s);
delete(s);

% Close videoinput object
delete(vid);
