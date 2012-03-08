#include <cv.h>
#include <highgui.h>

IplImage* GetThresholdedImage(IplImage* img) {
   IplImage* imgHSV = cvCreateImage(cvGetSize(img), 8, 3);
   cvCvtColor(img, imgHSV, CV_BGR2HSV);

   IplImage* imgThreshed = cvCreateImage(cvGetSize(img), 8, 1);
   cvInRangeS(imgHSV, cvScalar(20, 100, 100), cvScalar(30, 255, 255), imgThreshed);

   cvReleaseImage(&imgHSV);
   return imgThreshed;
}

int main(){
   IplImage* img = cvLoadImage("vest_test.jpg");

   if (!img) {
      printf("Could not load image file! \n");
      exit(0);
   }

   IplImage* imgYellowThresh = GetThresholdedImage(img);
  
   int x, y, count;
   x = y = count = 0;
   for(int i = 0; i <= imgYellowThresh->imageSize; i++){
      if(*(imgYellowThresh->imageData + i) != 0){
         x += i % imgYellowThresh->width;
//         y += i / imgYellowThresh->width;
         count++;
      }
   }

   x /= count;
   
   int mid = imgYellowThresh->width / 2;
   
   if (x == mid) {
      printf("Nothing\n");
   } else {
      printf("%c\n", x > mid ? 'R' : 'L');
   }

//   printf("Centroid found at: (%d,%d)\n", x/count, y/count);

//   cvSaveImage("vest_thresholded.jpg", imgYellowThresh);

   cvReleaseImage(&img);
   cvReleaseImage(&imgYellowThresh);

   exit(0);
}
