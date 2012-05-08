#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <ncurses.h>

// get each character repeated by a held down key
// this is very tricky thanks to key repeat/buffering issues...
void delay(int c){
   if(halfdelay(5) != ERR){
      while(getch() == c){
         if(halfdelay(1) == ERR) return;
      }
   }
}

int main(int argc,char** argv){
   struct termios tty_opts;
   int tty_fd;
   FILE *controller;

   int c; 
   unsigned char speed;

   //==========================
   // Set up serial connection
   //==========================

   // open connection
   tty_fd=open("/dev/MotorController", O_WRONLY | O_NOCTTY | O_NDELAY);

   if(tty_fd == -1){
      perror("Unable to open device /dev/MotorController - ");
      exit(1);
   }else{
      fcntl(tty_fd, F_SETFL, 0);
   }

   tcgetattr(tty_fd, &tty_opts);

   // set baud rate
   cfsetospeed(&tty_opts, B9600);

   // no parity, 8N1
   tty_opts.c_cflag &= ~PARENB;
   tty_opts.c_cflag &= ~CSTOPB;
   tty_opts.c_cflag &= ~CSIZE;
   tty_opts.c_cflag |= (CS8 | CLOCAL);

   // apply settings
   tcsetattr(tty_fd, TCSANOW, &tty_opts);
  
   //=======================
   // Run
   //=======================
   
   // initialize curses
   initscr();
   cbreak();
   noecho();

   controller = fopen("/dev/MotorController", "w");

   // quit on 'q'
   while ((c = getch()) != 'q') {
      switch (c) {
         case 'w': // forwards
            speed = 112;
            write(tty_fd, &speed, 1);
            speed = 240;
            write(tty_fd, &speed, 1);
            delay(c);
            break;
         case 's': // reverse
            speed = 16;
            write(tty_fd, &speed, 1);
            speed = 144;
            write(tty_fd, &speed, 1);
            delay(c);
            break;
         case 'a': // left
            speed = 127;
            write(tty_fd, &speed, 1);
            speed = 129;
            write(tty_fd, &speed, 1);
            delay(c);
            break;
         case 'd': // right
            speed = 1;
            write(tty_fd, &speed, 1);
            speed = 255;
            write(tty_fd, &speed, 1);
            delay(c);
            break;
      }

      speed = 64;
      write(tty_fd, &speed, 1);
      speed = 192;
      write(tty_fd, &speed, 1);

      cbreak();
   }

   // clean up
   speed = 0;
   write(tty_fd, &speed, 1);

   close(tty_fd);
   
   // end curses mode
   endwin();

   exit(0);
}
