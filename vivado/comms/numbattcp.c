#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <time.h>
#include <termios.h>
#include <sys/socket.h>
#include <string.h>
#include <poll.h>
#include <netdb.h>
#include <getopt.h>
#include <fcntl.h>
#include <errno.h>
#include <arpa/inet.h>

int
main(int argc, char *argv[])
{
        int opt, i;
        char *ipstring;
        uint32_t port;
        struct pollfd fds[2];
        char buffer[4096];
        FILE *logfp;
        ssize_t count;
        time_t curtime;
        struct sockaddr_in servaddr;

        ipstring = "192.168.0.90";
        port = 12320;
        while ((opt = getopt(argc, argv, "d:p:")) != EOF)
                switch (opt)
                {
                case 'd':
                        ipstring = optarg;
                        break;
                case 'p':
                        port = strtol(optarg, 0, 0);
                        break;
                default:
                        fprintf(stderr, "%s: unknown option %c\n", argv[0], opt);
                        exit(1);
                }
        fds[0].fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fds[0].fd < 0)
        {
                fprintf(stderr, "%s: error %d opening %s: %s", argv[0], errno, ipstring, strerror(errno));
                return 1;
        }
        bzero(&servaddr, sizeof(servaddr));

        servaddr.sin_family = AF_INET;
        servaddr.sin_addr.s_addr = inet_addr(ipstring);
        servaddr.sin_port = htons(port);

        if (connect(fds[0].fd, (struct sockaddr *)&servaddr, sizeof(servaddr)) != 0)
        {
                fprintf(stderr, "%s: error %d connection with the server failed %s: %s", argv[0], errno, ipstring, strerror(errno));
                exit(1);
        }
        fds[0].events = POLLIN;

        fds[1].fd = fileno(stdin);
        fds[1].events = POLLIN;

        logfp = fopen("debug.log", "a");
        if (logfp == 0)
        {
                fprintf(stderr, "%s: cannot open debug.log\n", argv[0]);
                exit(1);
        }
        time(&curtime);
        fprintf(logfp, "\n\nDebug log started: %s\n\n", ctime(&curtime));

        while (poll(fds, 2, -1) != -1)
        {
                if (fds[0].revents == POLLIN)
                {
                        if ((count = read(fds[0].fd, buffer, sizeof(buffer))) != 0)
                        {
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
        close(fds[0].fd);
        fclose(logfp);
        return 0;
}
