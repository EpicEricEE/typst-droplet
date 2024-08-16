#import "/src/lib.typ": dropcap

#set page(width: 6cm, height: auto, margin: 1em)

// Test correct splitting with trailing line- and paragraph breaks.

#dropcap[This ends\ with a line break.\ But there is more!]

#dropcap[This ends\ with two line breaks.\ \ But there is more!]

#dropcap[
  This ends\ with a paragraph break.
  
  But there is more!
]