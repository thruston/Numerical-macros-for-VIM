#! /usr/bin/env python
# TeX-aware inline calculator/expression evaluator for Vim
# uses code in lumberjack.py
# Toby Thurston -- 05 Nov 2013 

from __future__ import division
from math import sqrt, log, exp, sin, cos, tan, asin, acos, atan, hypot, pi, e
import re

def workout(s):
    '''Do the arithmetic here, allowing for TeX input.

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

    '''

    s = s.replace(r'\times','*')
    s = s.replace(r'\left(','(')
    s = s.replace(r'\right)',')')
    s = re.sub(r'{(.*?)\\over(.*?)}', r'(\1/\2)', s)
    s = s.replace(r'^','**')
    s = s.replace(r'{', '(')
    s = s.replace(r'}', ')')
    s = s.replace(r'\\','')
    s = re.sub('(\d)([a-z\(])',r'\1*\2',s)
    return eval(s)

def find_expression(line,col):
    '''Given a line and a cursor pos, return a tuple of str (prefix, expression, suffix).
    Note the cursor position is 0 indexed.

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

    alphabet = 'abcdefghijklmnopqrstuvwxyz1234567890.-+*/^\\{}()'
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
        approx = float('%g' % answer)
        rel = '=' if answer==approx else '\\simeq'
        return '{0} {1} {2:g}'.format(target,rel,approx)
    
    if target.endswith("\\"):
        import fractions as f
        target = target.strip("\\")
        q = f.Fraction(workout(target)).limit_denominator()
        return '{0} = {{{1.numerator}\\over{1.denominator}}}'.format(target,q)
    
    return '{0}'.format(workout(target))

import vim

line = vim.current.line
(row,col) = vim.current.window.cursor

(prefix, expression, suffix) = find_expression(line,col)
answer = evaluate_expression(expression)
vim.current.line = prefix+answer+suffix
vim.current.window.cursor = (row,1+len(prefix+answer)) 

# Normal 4
