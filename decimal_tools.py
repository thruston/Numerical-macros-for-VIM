# encoding: utf-8
from __future__ import with_statement, division
from decimal import *
import re
import math

def pi():
    """Compute Pi to the current precision.

    >>> print pi()
    3.141592653589793238462643383

    """
    getcontext().prec += 2  # extra digits for intermediate steps
    three = Decimal(3)      # substitute "three=3.0" for regular floats
    lasts, t, s, n, na, d, da = 0, three, 3, 1, 0, 0, 24
    while s != lasts:
        lasts = s
        n, na = n+na, na+8
        d, da = d+da, da+32
        t = (t * n) / d
        s += t
    getcontext().prec -= 2
    return +s               # unary plus applies the new precision

def exp(x):
    """Return e raised to the power of x.  Result is a decimal.

    >>> print exp(Decimal(1))
    2.718281828459045235360287471
    >>> print exp(Decimal(2))
    7.389056098930650227230427461
    >>> print exp(2.0)
    7.389056098930650227230427461

    """
    if not hasattr(x,'quantize'):
        x = Decimal(str(x))
    with localcontext() as ctx:
        ctx.prec += 2
        i, lasts, s, fact, num = 0, 0, 1, 1, 1
        while s != lasts:
            lasts = s
            i += 1
            fact *= i
            num *= x
            s += num / fact
    return +s

def ln(x):
    """Return a=ln(x), such that e^a=x.

    >>> print ln(2)
    0.6931471805599453094172321215
    >>> print ln(Decimal("0.1"))
    -2.302585092994045684017991455

    """
    with localcontext() as ctx:
        ctx.prec += 2
        base = exp(Decimal(1))
        i_part = Decimal(0)
        if x<=0:
            raise ValueError, "x must be positive"

        # we want x in the range 1<x<base
        while x<1:    i_part -= 1; x *= base
        if x==1: return 0
        while x>base: i_part += 1; x /= base

        n = Decimal("0.5")
        x = x*x
        f_part      = Decimal(0)
        last_f_part = Decimal(1)
        while last_f_part != f_part:
            if x >= base:
                last_f_part = f_part
                f_part += n
                x /= base
            n /= 2
            x = x*x
        log = i_part+f_part
    return +log



def cos(x):
    """Return the cosine of x as measured in radians.

    >>> print cos(Decimal('0.5'))
    0.8775825618903727161162815826
    >>> print cos(0.5)
    0.87758256189
    >>> print cos(0.5+0j)
    (0.87758256189+0j)

    """
    getcontext().prec += 2
    i, lasts, s, fact, num, sign = 0, 0, 1, 1, 1, 1
    while s != lasts:
        lasts = s
        i += 2
        fact *= i * (i-1)
        num *= x * x
        sign *= -1
        s += num / fact * sign
    getcontext().prec -= 2
    return +s

def sin(x):
    """Return the sine of x as measured in radians.

    >>> print sin(Decimal('0.5'))
    0.4794255386042030002732879352
    >>> print sin(0.5)
    0.479425538604
    >>> print sin(-1.0)
    -0.841470984808
    >>> print sin(1.0)
    0.841470984808
    >>> print sin(10)
    -0.544021110889
    >>> print sin(0)
    0.0
    >>> print sin(pi()/2).normalize()
    1
    >>> print sin(pi()).normalize()
    0
    >>> print round(sin(pi()/3)**2,27)
    0.75
    >>> print round(sin(pi()/4)**2,27)
    0.5
    >>> print round(sin(pi()/6)**2,27)
    0.25


    """
    if not hasattr(x,'remainder_near'):
        return math.sin(x)

    p = pi(); two_p = p*2; half_p = p/2
    x = x.remainder_near(two_p) # first reduce so that -π<x<π
    if x < 0:  # now make it positive since sin(-a)=-sin(a)
        x_sign = -1
        x = abs(x)
    else:
        x_sign = 1

    if x>half_p: # now reduce it to first quadrant
        x = p-x

    with localcontext() as ctx:
        ctx.prec += 2
        i, lasts, s, fact, num, sign = 1, 0, x, 1, x, 1
        while s != lasts:
            lasts = s
            i += 2
            fact *= i * (i-1)
            num *= x * x
            sign = -sign
            s += num / fact * sign

        s*=x_sign

    return +s

def asin(x):
    """Return the arc-sine of x in radians, where -1<=x<=1

    >>> print asin(0)
    0
    >>> print asin(Decimal("0.5"))
    0.5235987755982988730771072305
    >>> print asin(Decimal("0.8"))
    0.9272952180016122324285124629
    >>> print (asin(Decimal("0.5").sqrt())==pi()/4)
    True
    >>> print (asin(Decimal(1))==pi()/2)
    True

    """
    if abs(x)>1: raise ValueError, "abs(x)>1"

    if x==-1:   return -pi()/2
    if x==-0.5: return -pi()/6
    if x==0:    return Decimal(0)
    if x==0.5:  return pi()/6
    if x==1:    return pi()/2

    if abs(x)>0.75:
        flip = x.as_tuple()[0]
        x = (1-x*x).sqrt() # work out acos instead and flip base to improve accuracy
    else:
        flip = -1

    getcontext().prec += 2
    i, lasts, s, fact, num = 0, 0, x, x, 1
    xs = x**2
    while s != lasts:
        lasts = s
        i += 2
        fact = fact*xs*(i-1)/i
        s = s + fact/(i+1)

    if flip==1:
        s = s-pi()/2
    elif flip==0:
        s = pi()/2-s

    getcontext().prec -=2
    return +s

def acos(x):
    """Return acos(x) == pi/2-asin(x)."""
    return pi()/2-asin(x)

def pow(x,y):
    """Return x^y with full generality.

    Won't be needed in Python 2.6+
    """
    if y==int(y):
        return x**y
    else:
        return exp(y*ln(x))

def gcd(n,m):
    """Return the greatest common divisor of n and m.

    >>> gcd(1437, 2349)
    3
    >>> gcd(8547,481)
    37
    >>> gcd(999,1001)
    1
    """
    while True:
       r = m%n
       if r==0: break
       m, n = n, r
    return n

def fact(n):
    """Return n factorial.

    >>> fact(-1)
    0
    >>> fact(0)
    1
    >>> fact(1)
    1
    >>> fact(2)
    2
    >>> fact(3)
    6
    >>> fact(4)
    24
    >>> fact(5)
    120
    >>> fact(6)
    720
    >>> fact(6.1)
    720
    """
    if n<0: return 0
    a = 1
    for b in range(2,int(n)+1):
        a *= b
    return a

def perm(n,r):
    """ Return the permutations of n things r at a time.

    >>> perm(0,0)
    1
    >>> perm(0,1)
    0
    >>> perm(1,1)
    1
    >>> perm(8,5)
    6720
    """
    if n<0: return 0
    if r<0: return 0
    if n<r: return 0
    z = 1
    for i in range(n-r+1,n+1):
        z *= i
    return z


def comb(n,r):
    """ Return the combinations of n things taken r at a time.

    >>> comb(0,0)
    1
    >>> comb(0,1)
    0
    >>> comb(1,1)
    1
    >>> comb(8,5)
    56
    >>> comb(52,13)
    635013559600L
    """
    if n<0: return 0
    if r<0: return 0
    if n<r: return 0
    if n-r<r: r=n-r              #  Adjust r

    z = 1
    for i in range(n-r+1,n+1):
        z*=i
    for i in range(2,r+1):
        z//=i
    return z


def sigfig(n,m):
    """Return n rounded to m significant figures.

    >>> sigfig(1,1)
    1
    >>> sigfig(pi(),4)
    Decimal('3.142')
    >>> sigfig(Decimal(123456),4)
    Decimal('123500')
    >>> sigfig(0,3)
    0
    """

    try:
        exponent = n.adjusted()
        base = Decimal("1E"+str(exponent))
        n /= base
        n = n.quantize(Decimal("1E-"+str(m-1)))
        n *= base
        return n+0
    except:
        return n

def factorize(n):
    """Return a list of factors of an integer (very slowly).

    >>> print factorize(4294966189)
    [53197, 80737]
    >>> print factorize(4294966271)
    [44617, 96263]
    >>> print factorize(4294966272)
    [2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 23, 89, 683]
    >>> print factorize(4294966339)
    [13187, 325697]
    >>> print factorize(4294966457)
    [14891, 288427]
    >>> print factorize(4294966464)
    [2, 2, 2, 2, 2, 2, 3, 3, 3, 2485513]
    >>> print factorize(4294966519)
    [34583, 124193]
    >>> print factorize(4294966573)
    [23071, 186163]
    >>> print factorize(4294966901)
    [37747, 113783]
    >>> print factorize(4294966969)
    [44201, 97169]
    >>> print factorize(4294966998)
    [2, 3, 7, 3917, 26107]
    >>> print factorize(4294967071)
    [65521, 65551]
    >>> print factorize(4294967291)
    [4294967291]
    >>> print factorize(4294967293)
    [9241, 464773]
    >>> print factorize(9)
    [3, 3]
    >>> print factorize(-1)
    -1
    >>> print factorize(4294966194)
    [2, 3, 3, 3, 3, 3, 3, 3, 53, 97, 191]
    >>> print factorize(4294966201)
    [12197, 352133]
    >>> print factorize(4294966400)
    [2, 2, 2, 2, 2, 2, 2, 5, 5, 1342177]
    >>> print factorize(4294966561)
    [36067, 119083]
    >>> print factorize(4294966631)
    [13729, 312839]
    >>> print factorize(4294966691)
    [39241, 109451]
    >>> print factorize(4294966759)
    [21649, 198391]
    >>> print factorize(4294966789)
    [50411, 85199]
    >>> print factorize(4294966896)
    [2, 2, 2, 2, 3, 3, 3, 11, 607, 1489]
    >>> print factorize(4294967099)
    [44483, 96553]
    >>> print factorize(4294967101)
    [23603, 181967]
    >>> print factorize(4294967213)
    [57139, 75167]
    >>> print factorize(4294967292)
    [2, 2, 3, 3, 7, 11, 31, 151, 331]
    """
    if n <=1:
        return n

    n = int(n)
    factors = []
    while n%2==0: factors.append(2); n//=2
    while n%3==0: factors.append(3); n//=3
    while n%5==0: factors.append(5); n//=5
    while n%7==0: factors.append(7); n//=7
    primes = [11, 13, 17, 19, 23, 29, 31, 37]
    i = 0
    keep_going = True;
    while keep_going:
        for j in range(8):
            p = i + primes[j]
            q = n//p
            if p>q:
                keep_going=False
                break
            while (n==q*p):
                factors.append(p)
                n=q
                q=n//p
        i+=30

    if n>1:
        factors.append(n)
    return factors



def looks_like_a_number(s):
    """Match a decimal constructor string.

    Using the definition in *BNF form in the Decimal class documentation
    sign           ::=  '+' | '-'
    digit          ::=  '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
    indicator      ::=  'e' | 'E'
    digits         ::=  digit [digit]...
    decimal-part   ::=  digits '.' [digits] | ['.'] digits
    exponent-part  ::=  indicator [sign] digits
    infinity       ::=  'Infinity' | 'Inf'
    nan            ::=  'NaN' [digits] | 'sNaN' [digits]
    numeric-value  ::=  decimal-part [exponent-part] | infinity
    numeric-string ::=  [sign] numeric-value | [sign] nan

    but ignoring the bits about 'Infinity' or 'NaN', we constrct a suitable
    regular express and return true if our single string argument matches.

    >>> looks_like_a_number("2")
    True
    >>> looks_like_a_number("-2E-3")
    True
    >>> looks_like_a_number("John")
    False
    >>> looks_like_a_number("e0")
    False
    >>> looks_like_a_number("")
    False

    """
    if re.match(r'\A[-+]?(\d+\.\d*|\.?\d+)([eE][-+]?\d+)?\Z',s):
        return True
    else:
        return False


if __name__ == "__main__":
    import doctest
    doctest.testmod()

