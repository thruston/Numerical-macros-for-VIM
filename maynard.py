#! /usr/bin/env python
# encoding: utf-8

# Toby Thurston -- 09 Aug 2015 

import vim
import decimal  
from decimal_tools import * # so that our methods override those in decimal 
import re
from date_tools import * 

def tokens_from(s):
    """Get commands, numbers, and operators from user input.

    This elaborate scheme turns user input into a stream of tokens and 
    allows the user to omit as many spaces as possible.  
    So "2 3+" produces "['2', '3', '+']"
    and "5sqrt" produces "['5', 'sqrt']"
    etc.

    Numbers, plain words, and unicode chars get pushed out first, 
    and for mixed input (like 5sqrt) we resort to a mini-tokenizer.
    a=words
    n=numbers
    o=other or operators with one character
    d=doubletons (eg ** ++ //) 
    x=variable length (but not a word or number)
    """
    tokens = []
    alphabet = ' <>abcdefghijklmnopqrstuvwxyz1234567890.+*/%s' % o['copy_char']
    typecast = 'saaaaaaaaaaaaaaaaaaaaaaaaaaaannnnnnnnnnndddxo' # keep o at the end so anything not found gets o
    for w in s.split():
        if looks_like_a_number(w): 
            tokens.append(w)
        elif re.match(r'^[a-z]+$', w): # take out the common case first
            tokens.append(w)
        elif w in [ "∞","¶","•","°","∑","π","∏","µ","√","∫","∂","∆","¬"]:
            tokens.append(w) # because the trick with the alphabet only works with single byte chars
        else:
            last_type = 's'
            token = ""
            for c in w:
                c_type = typecast[alphabet.find(c)]
                if   last_type == 's': token=c
                elif last_type == 'a' and c_type == 'a': token +=c
                elif last_type == 'n' and c_type == 'n': token +=c
                elif last_type == 'x' and c_type == 'x': token +=c
                elif last_type == 'd' and c_type == 'd': 
                    token += c
                    tokens.append(token)
                    token = ''
                    c_type = 's'
                elif c_type == 'o':
                    if token !='': 
                        tokens.append(token)
                        token = ''
                    tokens.append(c)
                    c_type = 's'
                else:
                    if token != '':
                        tokens.append(token)
                    token=c
                last_type = c_type 

            if token != '':
                tokens.append(token)
    return tokens

# todo:
def looks_like_an_expr(s): return False

def format_for_output(n):
    if o['fix_digits'] > 0:
        n = n.quantize(Decimal((0,(1,),int(-o['fix_digits']))))
        return str(n).rjust(o['precision'])
    return str(n)

stack = []
last_operands = []
memory = {}

def get(n=1):
    """Return a list of items off the stack
    or just one...

    Usage: a,b=get(2) etc.  Note: a=get(1) does *not* return a list...
    """
    while len(stack) < n:
        stack.insert(0,Decimal(0))
    while last_operands:
        last_operands.pop()
    if n<1:
        return None
    if n==1:
        a = stack.pop()
        last_operands.append(a)
        return a

    operands = []
    for i in range(n):
        a = stack.pop()
        operands.append(a)
        last_operands.insert(0,a)
    return operands

def put(*list):
    for n in list:
        stack.append(n)
    return

config_file = "/Users/toby/python/maynard.cfg"
config_lines = []
cfg = open(config_file)
units = {}
code_for = {}
o = { 'enter_key'  : "dup",              \
      'precision'  : getcontext().prec,  \
      'fix_digits' : 9,                  \
      'copy_char'  : '=',                \
    }

unit_line_pattern  = re.compile(r'^u:\s*(\S+)\s+(\S+)\s+(\S+)(\s+\S+)?')
cmd_line_pattern   = re.compile(r'^c:\s*(\S+)\s+(\S.*)')
stack_line_pattern = re.compile(r'^t:\s*(\S+)')
opt_line_pattern   = re.compile(r'^o:\s*(\S+)\s+(\S.*)')

for line in cfg:
    config_lines.append(line)

    m = unit_line_pattern.match(line)
    if m != None:
        units[m.group(2).lower()] = m.groups()
        continue

    m = cmd_line_pattern.match(line)
    if m != None:
        key = m.group(1).lower()
        value = m.group(2)
        # allow synonyms...
        if value in code_for:
            code_for[key] = code_for[value]
        else:
            code_for[key] = value
        continue
    
    m = stack_line_pattern.match(line)
    if m != None:
        stack.append(Decimal(m.group(1)))
        continue

    m = opt_line_pattern.match(line)
    if m != None:
        key = m.group(1).lower()
        try:
            o[key] = int(m.group(2))
        except:
            o[key] = m.group(2)
        continue

cfg.close()

want_more = 1
msg = ''
pending_unit = ''

while want_more:
    header = str('-P['+str(o['precision'])+']D['+str(o['fix_digits'])+']-').ljust(o['precision'],'-') + '\n'
    prompt = msg + header + '\n'.join(map(format_for_output, stack[:])) + '\nMaynard: '
    msg = ''
    vim.command("redraw!")
    vim.command("let expr = input('" + prompt + "')")
    user_input = vim.eval('expr')
    if user_input in "quit bye exit".split():
        break
    if user_input == "": user_input = o['enter_key']

    for token in tokens_from(user_input):
        if re.match(r'\A%s+\Z' % o['copy_char'],token):
            for x in stack[-len(token):]:
                # use gI so it goes in column 1 (slightly more sane like that)
                # consider stripping leading blanks?
                vim.command("normal gI" + format_for_output(x) + "\n")
        elif looks_like_a_number(token): put(decimal.Decimal(token))
        elif looks_like_an_expr(token):  put(decimal.Decimal(str(eval(token))))
        elif token in code_for:  
            try:
                exec(code_for[token])
            except:
                reason = str(sys.exc_info()[1]).replace("'",'"')
                msg = code_for[token] + ' caused an exception\n-> '+reason+'\n' 
        elif token == "fix": 
            o['fix_digits']=stack.pop()
            if o['fix_digits']>=o['precision']:
                o['precision'] = int(o['fix_digits']+2)
                getcontext().prec = o['precision']
        elif token == "all": o['fix_digits']=0
        elif token == "prec": 
            o['precision'] = int(stack.pop());
            getcontext().prec=o['precision']
            if o['precision']<o['fix_digits']:
                o['fix_digits'] = o['precision'] - 2
            
        elif token in units:
            if pending_unit == '':
                pending_unit = token
                msg = "Pending unit: " + token + "\n"
            elif units[pending_unit][0] != units[token][0]:
                pending_unit = ''
            else:
                a = stack.pop()
                msg = str(sigfig(a,4))+' '+pending_unit+' ~ '
                a *= Decimal(str(eval(units[pending_unit][2])))
                a /= Decimal(str(eval(units[token][2])))
                put(a)
                pending_unit = ''
                msg += str(sigfig(a,4))+' '+token+'\n'
        elif token == "~":
            msg = ':'.join(sorted(code_for.keys())) + '\n'
        elif token == "µ":
            msg = '\n'.join(r'%d -> %s' % (k,v) for (k,v) in memory.iteritems()) + '\n'
        elif token == "?": 
            msg = """Brother Maynard - a simple RPN calculator for VIM in Python
                  Use it a bit like an HP calculator, ie 2 2 + will produce 4
                  "quit" to finish; "=" copies the "top" of the stack to your current buffer.

                  "... and the number of the counting shall be three."
                  """
        else: 
            msg = "Ignored >>" + token + "<<\n"

new_cfg = open(config_file, 'w')

had_blank = True

for line in config_lines:
    m = stack_line_pattern.match(line)
    if m != None:
        continue

    m = opt_line_pattern.match(line)
    if m != None:
        continue

    if line.strip():
        had_blank = False
    else:
        if had_blank:
            continue
        else:
            had_blank = True

    new_cfg.write(line)

for key in o:
    new_cfg.write('o: %s %s\n' % (str(key),str(o[key]))) # dokey  

for item in stack:
    new_cfg.write('t: %s\n' % str(item))
    
new_cfg.close()
