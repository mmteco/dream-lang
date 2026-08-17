#include <math.h>

int int_floordiv(int left, int right) {
    int quotient = left / right;
    if ((left % right != 0) && ((left < 0) != (right < 0))) {
        quotient = quotient - 1;
    }
    return quotient;
}

double float_floordiv(double left, double right) {
    return floor(left / right);
}

int int_pow(int base, int exponent) {
    int result = 1;
    while (exponent > 0) {
        result = result * base;
        exponent = exponent - 1;
    }
    return result;
}

double float_pow(double base, double exponent) {
    return pow(base, exponent);
}
