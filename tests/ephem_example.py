#!/usr/bin/env python3

import ephem
mars = ephem.Mars()
mars.compute('2007/10/02 00:50:22')
print(mars.ra, mars.dec)
print("Should be: 6:05:56.34 23:23:40.0")
print(ephem.constellation(mars))
print("Should be: ('Gem', 'Gemini')")

