#include <stdio.h>

extern void assFunc(int x, int y);

char c_checkValidity(int x, int y)
{
    if (x >= y)
        return 1;
    return 0;
}

int main(int argc, char** argv)
{
    int x, y;
    char buffer[10];
    printf("Enter 2 numbers:\n");

    fgets(buffer, 9, stdin);
    sscanf(buffer, "%d", &x);

    fgets(buffer, 9, stdin);
    sscanf(buffer, "%d", &y);

    assFunc(x,y);
    
    return 0;
}