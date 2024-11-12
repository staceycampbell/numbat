#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <getopt.h>
#include <poll.h>

// https://stackoverflow.com/a/6947758

static int
set_interface_attribs(int fd, int speed, int parity)
{
        struct termios tty;
        if (tcgetattr(fd, &tty) != 0)
        {
                fprintf(stderr, "%s: error %d from tcgetattr", __PRETTY_FUNCTION__, errno);
                return -1;
        }

        cfsetospeed(&tty, speed);
        cfsetispeed(&tty, speed);

        tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;     // 8-bit chars
        // disable IGNBRK for mismatched speed tests; otherwise receive break
        // as \000 chars
        tty.c_iflag &= ~IGNBRK; // disable break processing
        tty.c_lflag = 0;        // no signaling chars, no echo,
        // no canonical processing
        tty.c_oflag = 0;        // no remapping, no delays
        tty.c_cc[VMIN] = 0;     // read doesn't block
        tty.c_cc[VTIME] = 5;    // 0.5 seconds read timeout

        tty.c_iflag &= ~(IXON | IXOFF | IXANY); // shut off xon/xoff ctrl

        tty.c_cflag |= (CLOCAL | CREAD);        // ignore modem controls,
        // enable reading
        tty.c_cflag &= ~(PARENB | PARODD);      // shut off parity
        tty.c_cflag |= parity;
        tty.c_cflag &= ~CSTOPB;
        tty.c_cflag &= ~CRTSCTS;

        if (tcsetattr(fd, TCSANOW, &tty) != 0)
        {
                fprintf(stderr, "%s: error %d from tcsetattr", __PRETTY_FUNCTION__, errno);
                return -1;
        }
        return 0;
}

static void
set_blocking(int fd, int should_block)
{
        struct termios tty;
        memset(&tty, 0, sizeof tty);
        if (tcgetattr(fd, &tty) != 0)
        {
                fprintf(stderr, "%s: error %d from tggetattr", __PRETTY_FUNCTION__, errno);
                return;
        }

        tty.c_cc[VMIN] = should_block ? 1 : 0;
        tty.c_cc[VTIME] = 5;    // 0.5 seconds read timeout

        if (tcsetattr(fd, TCSANOW, &tty) != 0)
                fprintf(stderr, "%s: error %d setting term attributes", __PRETTY_FUNCTION__, errno);
}

int
main(int argc, char *argv[])
{
        int opt, i;
        char *portname;
        struct pollfd fds[2];
        char buffer[4096];
        FILE *logfp;
        ssize_t count;

        portname = "/dev/ttyUSB1";
        while ((opt = getopt(argc, argv, "d:")) != EOF)
                switch (opt)
                {
                case 'd':
                        portname = optarg;
                        break;
                default:
                        fprintf(stderr, "%s: unknown option %c\n", argv[0], opt);
                        exit(1);
                }
        fds[0].fd = open(portname, O_RDWR | O_NOCTTY | O_SYNC);
        if (fds[0].fd < 0)
        {
                fprintf(stderr, "%s: error %d opening %s: %s", argv[0], errno, portname, strerror(errno));
                return 1;
        }

        set_interface_attribs(fds[0].fd, B115200, 0);   // set speed to 115,200 bps, 8n1 (no parity)
        set_blocking(fds[0].fd, 1);     // set blocking
        fds[0].events = POLLIN;

        fds[1].fd = fileno(stdin);
        fds[1].events = POLLIN;

        logfp = fopen("debug.log", "w");
        if (logfp == 0)
        {
                fprintf(stderr, "%s: cannot open debug.log\n", argv[0]);
                exit(1);
        }

        while (poll(fds, 2, -1) != -1)
        {
                if (fds[0].revents == POLLIN)
                {
                        if ((count = read(fds[0].fd, buffer, sizeof(buffer))) != 0)
                        {
                                fprintf(logfp, "to GUI: ");
                                for (i = 0; i < count; ++i)
                                        fputc(buffer[i], logfp);
                                fflush(logfp);
                                write(fileno(stdout), buffer, count);
                        }
                }
                if (fds[1].revents == POLLIN)
                {
                        if ((count = read(fds[1].fd, buffer, sizeof(buffer))) != 0)
                        {
                                fprintf(logfp, "to ENG: ");
                                fflush(logfp);
                                i = 0;
                                while (i < count)
                                {
                                        fputc(buffer[i], logfp);
                                        write(fds[0].fd, &buffer[i], 1);
                                        usleep(1000);
                                        ++i;
                                }
                                fflush(logfp);
                        }
                }
        }
        return 0;
}
