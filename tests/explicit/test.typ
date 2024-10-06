#import "/src/lib.typ": dropcap

#set page(width: 6cm, height: auto, margin: 1em)

// Test explicitly passed first letter.

#dropcap(square(size: 1em), gap: 1em)[A square is a square.]
#dropcap(square(size: 1em), gap: 1em, height: 3, lorem(13))
#dropcap(square(), height: 14pt, gap: 1em, lorem(10))
#dropcap[\#1][The winner has won what was to win.]
#dropcap(height: auto, gap: 1em)[
  #figure(rect(), caption: [Rect])
][
  To the left is a rectangle inside a figure with a caption, that this text is wrapped around.
]
