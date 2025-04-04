/*
 * Userspace program that communicates with the vga_ball device driver
 * through ioctls
 *
 * Stephen A. Edwards
 * Columbia University
 */

#include <stdio.h>
#include "vga_ball.h"
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

int vga_ball_fd;

/* Read and print the background color */
void print_background_color() {
  vga_ball_arg_t vla;
  
  if (ioctl(vga_ball_fd, VGA_BALL_READ_BACKGROUND, &vla)) {
      perror("ioctl(VGA_BALL_READ_BACKGROUND) failed");
      return;
  }
  printf("%02x %02x %02x\n",
	 vla.background.red, vla.background.green, vla.background.blue);
}
void print_center(){
  vga_ball_arg_t vla;
  if (ioctl(vga_ball_fd, VGA_BALL_READ_CENTER, &vla)) {
      perror("ioctl failed");
      return;
  }
}

/* Set the background color */
void set_background_color(const vga_ball_color_t *c)
{
  vga_ball_arg_t vla;
  vla.background = *c;
  if (ioctl(vga_ball_fd, VGA_BALL_WRITE_BACKGROUND, &vla)) {
      perror("ioctl(VGA_BALL_SET_BACKGROUND) failed");
      return;
  }
}

void set_center(const vga_ball_center_t *c)
{
  if (ioctl(vga_ball_fd,VGA_BALL_WRITE_CENTER, c)){
	perror("ioctl failed");
	return; 
  }
}

int main()
{
  vga_ball_arg_t vla;
  int i;
  static const char filename[] = "/dev/vga_ball";

  static const vga_ball_color_t colors[] = {
    { 0xff, 0x00, 0x00 }, /* Red */
    { 0x00, 0xff, 0x00 }, /* Green */
    { 0x00, 0x00, 0xff }, /* Blue */
    { 0xff, 0xff, 0x00 }, /* Yellow */
    { 0x00, 0xff, 0xff }, /* Cyan */
    { 0xff, 0x00, 0xff }, /* Magenta */
    { 0x80, 0x80, 0x80 }, /* Gray */
    { 0x00, 0x00, 0x00 }, /* Black */
    { 0xff, 0xff, 0xff }  /* White */
  };
  static vga_ball_center_t center;
  int x=100,y=100;
  center.x=x;
  center.y=y;
  int dx=1;
  int dy=1;
  int x_min=0;
  int y_min=0;
  int x_max=640;
  int y_max=480;
  int r = 15;
  i =0;
# define COLORS 9

  printf("VGA ball Userspace program started\n");

  if ( (vga_ball_fd = open(filename, O_RDWR)) == -1) {
    fprintf(stderr, "could not open %s\n", filename);
    return -1;
  }

  while(1){
    x+=dx;
    y+=dy;
    if (x >= x_max-r){
	dx=-dx;
	x=x_max-r;
	set_background_color(&colors[i%COLORS]);
	i=(i+1)%COLORS;

    }
    else if (x<=r){
 	dx=-dx;
	x=r;
	set_background_color(&colors[i%COLORS]);
        i=(i+1)%COLORS;

    }
    else if (y >= y_max-r){
        dy=-dy;
	y=y_max-r;
	set_background_color(&colors[i%COLORS]);
        i=(i+1)%COLORS;
	
    }
    else if (y<=r) {
	dy=-dy;
        y=r;
	set_background_color(&colors[i%COLORS]);
        i=(i+1)%COLORS;

    }
    center.x=x;
    center.y=y;

    set_center(&center);
    print_center();

    usleep(10000);

  }
  


  printf("VGA BALL Userspace program terminating\n");
  return 0;
}
