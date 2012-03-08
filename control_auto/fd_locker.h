#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

#ifndef _FD_LK_CHK
#define _FD_LK_CHK
struct flock fl = {F_RDLCK, SEEK_SET, 0, 0, 0};
#endif

static inline void rd_lock(int fd){
   if (fl.l_pid == 0) fl.l_pid = getpid();

   fl.l_type = F_RDLCK;

   if(fcntl(fd, F_SETLKW, &fl) == -1){
      perror("fcntl unable to set read lock");
      exit(1);
   }
}

static inline void wr_lock(int fd){
   if (fl.l_pid == 0) fl.l_pid = getpid();

   fl.l_type = F_WRLCK;
   
   if(fcntl(fd, F_SETLKW, &fl) == -1){
      perror("fcntl unable to set read lock");
      exit(1);
   }
}

static inline void unlock(int fd){
   fl.l_type = F_UNLCK;

   if(fcntl(fd, F_SETLK, &fl) == -1){
      perror("fcntl unable to set read lock");
      exit(1);
   }
}
