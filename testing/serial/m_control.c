#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <ncurses.h>

void delay(int c){
   if(halfdelay(6) != ERR){
      while(getch() == c){
         if(halfdelay(1) == ERR) return;
      }
   }
}

int main(int argc,char** argv){
   struct termios tty_opts;
   int tty_fd;

   int c, speed;

   //==========================
   // Set up serial connection
   //==========================

   // open connection
   tty_fd=open("/dev/ttts7", O_WRONLY | O_NOCTTY | O_NDELAY);

   if(tty_fd == -1){
      perror("Unable to open device /dev/ttts7 - ");
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

   while ((c = getch()) != 'q') {
      switch (c) {
         case 's': // reverse
            speed = 96; 
            write(tty_fd, &speed, 1);
            speed = 224;
            write(tty_fd, &speed, 1);

            delay(c);
            break;
         case 'w': // forwards
            speed = 32;
            write(tty_fd, &speed, 1);
            speed = 160;
            write(tty_fd, &speed, 1);

            delay(c);
            break;
         case 'd': // right
            speed = 96;
            write(tty_fd, &speed, 1);
            speed = 160;
            write(tty_fd, &speed, 1);
            
            delay(c);
            break;
         case 'a': // left
            speed = 32;
            write(tty_fd, &speed, 1);
            speed = 224;
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
