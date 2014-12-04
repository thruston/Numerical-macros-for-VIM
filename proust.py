"""A TeX-aware inline calculator/expression evaluator for Vim

Toby Thurston -- 04 Dec 2014 
"""

from __future__ import division, print_function
from math import sqrt, log, exp, sin, cos, tan, asin, acos, atan, hypot, pi, e, ceil, floor, factorial, fabs, degrees, radians
import re

phi = 1.61803398875

def sind(x):
    """
    Sine of x in degrees.

    >>> abs(sind(45)-sqrt(1/2))<1e-15
    True
    """
    return sin(radians(x))

def cosd(x):
    '''Cosine of x in degrees

    >>> abs(cosd(30)-sqrt(3/4))<1e-15
    True
    '''
    return cos(radians(x))

def tand(x):
    return sind(x)/cosd(x)

def choose(n, k):
    '''A fast way to calculate binomial coefficients by Andrew Dalke (contrib).

    >>> choose(4,2)
    6
    >>> choose(2,4)
    0
    >>> choose(20,8)
    125970
    '''
    if 0 <= k <= n:
        ntok = 1
        ktok = 1
        for t in xrange(1, min(k, n - k) + 1):
            ntok *= n
            ktok *= t
            n -= 1
        return ntok // ktok
    return 0

def workout(s):
    '''De-Texify the expression then call eval().
    Also spot units.

    >>> workout('1+1')
    2
    >>> workout(r'37\\times27')
    999
    >>> workout('{55\over6}')
    9.166666666666666
    >>> workout('2^8+pi')
    259.1415926535898
    >>> workout(r'\\\\sqrt(3)')
    1.7320508075688772
    >>> workout('3e^-3')
    0.14936120510359185
    >>> workout('210mm-3in')
    379.2755905509

    '''

    s = s.replace(r'\times','*')
    s = s.replace(r'\left(','(')
    s = s.replace(r'\right)',')')
    s = re.sub(r'{(.*?)\\over(.*?)}', r'((\1)/(\2))', s)
    s = re.sub(r'{(.*?)\\choose(.*?)}', r'choose(\1,\2)', s)
    s = s.replace(r'^','**')
    s = s.replace(r'{', '(')
    s = s.replace(r'}', ')')
    s = s.replace('\\','')
    s = re.sub('(\d)!',r'factorial(\1)',s)
    s = re.sub('([0-9\)])([a-z\(])',r'\1*\2',s)
    s = re.sub('(\d+)\*mm',r'(\1*2.83464566929)',s)
    s = re.sub('(\d+)\*in',r'(\1*72)',s)
    s = re.sub('(\d+)\*bp',r'(\1*1)',s)
    s = re.sub('(\d+)\*pt',r'(\1*0.996264009963)',s)
    try:
        answer = eval(s)
    except SyntaxError:
        answer = '['+s+']'
    return answer

def find_expression(line,col):
    '''Given a line and a cursor pos, return a tuple of str (prefix, expression, suffix).

    Note that the cursor position is 0 indexed.
    Note trailing and leading blanks are preserved.

    >>> find_expression('',0)
    ('', '', '')
    >>> find_expression('This one is 3+4 easy', 15)
    ('This one is ', '3+4', ' easy')
    >>> find_expression('A bit harder', 0)
    ('', '', 'A bit harder')
    >>> find_expression('# Normal 2+2', 11)
    ('# Normal ', '2+2', '')

    >>> find_expression('12',1)
    ('', '12', '')
    
    >>> find_expression('12 ',2)
    ('', '12', ' ')
    
    >>> find_expression('12 ',2)
    ('', '12', ' ')

    >>> find_expression('String 3+4=',10)
    ('String ', '3+4=', '')
    

    '''

    if len(line)==0:
        return ('', '', '')

    if col==0:
        return ('', '', line)

    alphabet = 'abcdefghijklmnopqrstuvwxyz1234567890!,.-+*/^\\{}()'
    target = ''
    p = col
    while p>=0:
        c = line[p]
        p -= 1
        if 0==len(target):
            if c in '='+alphabet:
                target = c
            elif c == ' ':
                col -= 1
        elif c in alphabet:
            target = c + target
        else:
            p = p+1
            break

    return (line[0:p+1], target, line[col+1:])

def evaluate_expression(target):
    '''Check for terminal "signals" and call workout accordingly.
    
    If the expression ends in "=" then answer is "expr = answer".
    If the expression ends in "\" then make the answer a fraction.
    Otherwise just replace the expr with the answer.

    >>> evaluate_expression('3+4=')
    '3+4 = 7'
    >>> evaluate_expression(r'0.5\\\\')
    '0.5 = {1\\\\over2}'
    >>> evaluate_expression('')
    ''

    '''
    if not target:
        return ''

    if target.endswith('='):
        target = target.strip('=')
        answer = workout(target)
        try:
            approx = float('%g' % answer)
            rel = '=' if fabs(answer-approx)<1e-15 else '\\simeq'
            return '{0} {1} {2:g}'.format(target,rel,approx)
        except:
            return answer+'?'
    
    if target.endswith("\\"):
        import fractions as f
        target = target.strip("\\")
        q = f.Fraction(workout(target)).limit_denominator()
        return '{0} = {{{1.numerator}\\over{1.denominator}}}'.format(target,q)
    
    return '{0}'.format(workout(target))

if __name__ == '__main__':
    try:
        import vim
        line = vim.current.line
        (row,col) = vim.current.window.cursor

        (prefix, expression, suffix) = find_expression(line,col)
        answer = evaluate_expression(expression)
        vim.current.line = prefix+answer+suffix
        vim.current.window.cursor = (row,1+len(prefix+answer)) 
    except ImportError:
        pass


