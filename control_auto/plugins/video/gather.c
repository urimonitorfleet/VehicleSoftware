#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <cv.h>
#include <highgui.h>

// Threshold the input image based on a color in the HSV map
IplImage* GetThresholdedImage(IplImage* img) {
   IplImage* imgHSV = cvCreateImage(cvGetSize(img), 8, 3);
   cvCvtColor(img, imgHSV, CV_BGR2HSV);

   IplImage* imgThreshed = cvCreateImage(cvGetSize(img), 8, 1);
   cvInRangeS(imgHSV, cvScalar(32, 50, 125, 0), cvScalar(43, 255, 255, 0), imgThreshed);

   cvReleaseImage(&imgHSV);
   return imgThreshed;
}

int main(int argc, char *argv[]){

   FILE *out_file;
   int fd, i, x, y, count;
   IplImage *img, *imgThresh;

   if((fd = open("/tmp/data/video", O_CREAT|O_TRUNC|O_WRONLY, 0644)) == -1){
      perror("unable to open file descriptor");
      exit(1);
   }
   
   if(flock(fd, LOCK_EX) == -1){
      perror("error acquiring lock");
      return 1;
   }

   if(!(out_file = fdopen(fd, "w"))){
      perror("unable to open file");
      exit(1);
   }

   if(!(img = cvLoadImage(argv[1], CV_LOAD_IMAGE_COLOR))){
      perror("could not load image file");
      return 1;
   }

   imgThresh = GetThresholdedImage(img);

   x = y = count = 0;
   for(i = 0; i <= imgThresh->imageSize; i++){
      if(*(imgThresh->imageData + i) != 0){
         x += i % imgThresh->width;
         count++;
      }
   }

   if(count > 250){
      fprintf(out_file, "cent_x|%i\narea|%i\n", x/count, count);
   }else{
      fprintf(out_file, "cent_x|-1\narea|-1\n");
   }

   cvReleaseImage(&img);
   cvReleaseImage(&imgThresh);

   if(flock(fd, LOCK_UN) == -1){
      perror("error releasing lock");
      return 1;
   }

   if(fclose(out_file) == -1){
      perror("couldn't close file");
      return 1;
   }

   return 0;
}
