#!/bin/python
 
import sys
 
PRICE_PER_CASE = 20
REBATE = 20
CASES_FOR_REBATE = 2
HEADER_FMT = '{:>4} {:>16} {:>16}'
ROW_FMT = '{:4d} {:16.2f} {:16.2f}'
 
def usage():
    print('Usage: {} <number of cases>'.format(sys.argv[0]))
    exit(1)
 
if __name__ == '__main__':
    if len(sys.argv) != 2:
        usage()
 
    try:
        count = int(sys.argv[1])
    except ValueError:
        usage()
 
    print(HEADER_FMT.format('n', 'total price ($)', 'unit price ($)'))
 
    for n in range(1, count + 1):
        total_price = n * PRICE_PER_CASE - (REBATE * ((n - 1) // CASES_FOR_REBATE))
        unit_price = total_price / n
        print(ROW_FMT.format(n, total_price, unit_price))
