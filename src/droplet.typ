// Regex for valid characters in front of the dropped capital.
#let regex-before = regex({
  "["
    "\"'"    // Dumb quotes
    "\p{C}"  // Control characters
    "\p{Pi}" // Initial punctuation
    "\p{Ps}" // Opening punctuation
    "\p{Z}"  // Spaces and separators
  "]+"
})

// Regex for valid characters behind the dropped capital.
#let regex-after = regex({
  "["
    "\."     // Full stop
    "'"      // Apostrophe
    "\p{C}"  // Control characters
    "\p{Pf}" // Final punctuation
    "\p{Pe}" // Closing punctuation
    "\p{Z}"  // Spaces and separators
    "\p{M}"  // Combining marks
  "]+"
})

// Element function for space.
#let space = [ ].func()

// Elements that can be split and have a 'body' field.
#let splittable = (strong, emph, underline, stroke, overline, highlight)

// Sets the font size so the resulting text height matches the given height.
//
// If not specified otherwise in "text-args", the top and bottom edge of the
// resulting text element will be set to "bounds".
//
// Parameters:
// - height: The target height of the resulting text.
// - threshold: The maximum difference between target and actual height.
// - text-args: Arguments to be passed to the underlying text element.
// - body: The content of the text element.
//
// Returns: The text with the set font size.
#let sized(height, ..text-args, threshold: 0.1pt, body) = style(styles => {
  let text = text.with(
    top-edge: "bounds",
    bottom-edge: "bounds",
    ..text-args.named(),
    body
  )

  let size = height
  let font-height = measure(text(size: size), styles).height

  // This should only take one iteration, but just in case...
  while calc.abs(font-height - height) > threshold {
    size *= 1 + (height - font-height) / font-height
    font-height = measure(text(size: size), styles).height
  }

  return text(size: size)
})

// Attaches a label after the split elements.
//
// The label is only attached to one of the elements, preferring the second
// one. If both elements are empty, the label is discarded. If the label is
// empty, the elements remain unchanged.
#let attach-label((first, second), label) = {
  if label == none {
    (first, second)
  } else if second != none {
    (first, [#second#label])
  } else if first != none {
    ([#first#label], second)
  } else {
    (none, none)
  }
}

// Converts the given content to a string.
#let to-string(body) = {
  if type(body) == str {
    body
  } else if body.has("text") {
    to-string(body.text)
  } else if body.has("child") {
    to-string(body.child)
  } else if body.has("children") {
    body.children.map(to-string).join()
  } else if body.func() in splittable {
    to-string(body.body)
  } else if body.func() == smartquote {
    // Unfortunately, we can only use "dumb" quotes here.
    if body.double { "\"" } else { "'" }
  } else if body.func() == enum.item {
    str(body.number) + "."
  } else if body.func() == space {
    " "
  } else {
    ""
  }
}

// Tries to extract the first letter of the given content.
//
// If the first letter cannot be extracted, the whole body is returned as rest.
//
// Returns: A tuple of the first letter and the rest.
#let extract-first-letter(body) = {
  if type(body) == str {
    let letter = body.clusters().at(0, default: none)
    if letter == none {
      return (none, body)
    }
    let rest = body.clusters().slice(1).join()
    return (letter, rest)
  }

  if body.has("text") {
    let (text, ..fields) = body.fields()
    let label = if "label" in fields { fields.remove("label") }
    let func(it) = if it != none { body.func()(..fields, it) }
    let (letter, rest) = extract-first-letter(body.text)
    return attach-label((letter, func(rest)), label)
  }

  if body.func() in splittable {
    let (body: text, ..fields) = body.fields()
    let label = if "label" in fields { fields.remove("label") }
    let func(it) = if it != none { body.func()(..fields, it) }
    let (letter, rest) = extract-first-letter(text)
    return attach-label((letter, func(rest)), label)
  }

  if body.func() == enum.item {
    let (body, number) = body.fields()
    return if number < 10 {
      (str(number), "." + body)
    } else {
      (str(number).first(), str(number).slice(1) + "." + body)
    }
  }

  if body.has("child") {
    // We cannot create a 'styled' element, so set/show rules are lost.
    let (letter, rest) = extract-first-letter(body.child)
    return (letter, rest)
  }

  if body.has("children") {
    let child-pos = body.children.position(c => {
      c.func() not in (space, parbreak)
    })

    if child-pos == none {
      // There is no letter to extract.
      return (none, body)
    }

    let child = body.children.at(child-pos)
    let (letter, rest) = extract-first-letter(child)
    if body.children.len() > child-pos {
      rest = (rest, ..body.children.slice(child-pos+1)).join()
    }
    return (letter, rest)
  }

  // Element cannot be split further.
  return (body, none)
}

// Gets the number of words in the given content.
#let size(body) = {
  if type(body) == str {
    body.split(" ").len()
  } else if body.has("text") {
    size(body.text)
  } else if body.has("child") {
    size(body.child)
  } else if body.has("children") {
    body.children.map(size).sum()
  } else if body.func() in splittable {
    size(body.body)
  } else if body.func() == space {
    0
  } else {
    1
  }
}

// Tries to split the given content at a given index.
//
// Content is split at word boundaries. A sequence can be split at any of its
// childrens' word boundaries.
//
// Returns: A tuple of the first and second part.
#let split(body, index) = {
  if type(body) == str {
    let words = body.split(" ")
    if index >= words.len() {
      return (body, none)
    }
    let first = words.slice(0, index).join(" ")
    let second = words.slice(index).join(" ")
    return (first, second)
  }

  if body.has("text") {
    let (text, ..fields) = body.fields()
    let label = if "label" in fields { fields.remove("label") }
    let func(it) = if it != none { body.func()(..fields, it) }
    let (first, second) = split(text, index)
    return attach-label((func(first), func(second)), label)
  }

  if body.func() in splittable {
    let (body: text, ..fields) = body.fields()
    let label = if "label" in fields { fields.remove("label") }
    let func(it) = if it != none { body.func()(..fields, it) }
    let (first, second) = split(text, index)
    return attach-label((func(first), func(second)), label)
  }

  if body.has("child") {
    // We cannot create a 'styled' element, so set/show rules are lost.
    let (first, second) = split(body.child, index)
    return (first, second)
  }

  if body.has("children") {
    let first = ()
    let second = ()

    // Find child containing the splitting point and split it.
    let new-index = index
    for (i, child) in body.children.enumerate() {
      let child-size = size(child)
      new-index -= child-size

      if new-index <= 0 {
        // Current child contains splitting point.
        let sub-index = child-size + new-index
        let (child-first, child-second) = split(child, sub-index)

        if child-second == none {
          // Split is at the end of the child, so check if next child is space.
          let next = body.children.at(i + 1, default: [ ])
          if next.func() != space {
            // Cannot split here, so split at previous break point.
            return split(body, index - 1)
          }
        }

        first.push(child-first)
        second.push(child-second)
        second += body.children.slice(i + 1) // Add remaining children
        break
      } else {
        first.push(child)
      }
    }

    return (first.join(), second.join())
  }

  // Element cannot be split further.
  return (body, none)
}

// Shows the first letter of the given content in a larger font.
//
// If the first letter is not given as a positional argument, it is extracted
// from the content. The rest of the content is split into two pieces, where
// one is positioned next to the dropped capital, and the other below it.
//
// Parameters:
// - height: The height of the first letter. Can be given as the number of
//           lines (integer) or as a length.
// - justify: Whether to justify the text next to the first letter.
// - gap: The space between the first letter and the text.
// - hanging-indent: The indent of lines after the first line.
// - overhang: The amount by which the first letter should overhang into the
//             margin. Ratios are relative to the width of the first letter.
// - transform: A function to be applied to the first letter.
// - text-args: Named arguments to be passed to the underlying text element.
// - body: The content to be shown.
//
// Returns: The content with the first letter shown in a larger font.
#let dropcap(
  height: 2,
  justify: false,
  gap: 0pt,
  hanging-indent: 0pt,
  overhang: 0pt,
  transform: none,
  ..text-args,
  body
) = layout(bounds => style(styles => {  
  let (letter, rest) = if text-args.pos() == () {
    // Split body into first letter and rest of string.
    let (letter, rest) = extract-first-letter(body)

    // Prepend valid characters before the first letter.
    while to-string(letter).last().match(regex-before) != none {
      let (next-letter, new-rest) = extract-first-letter(rest)
      if next-letter == none { break }
      letter += next-letter
      rest = new-rest
    }

    // Append valid characters after the first letter.
    let (next-letter, new-rest) = extract-first-letter(rest)
    while next-letter != none and to-string(next-letter).match(regex-after) != none {
      letter += next-letter
      rest = new-rest
      (next-letter, new-rest) = extract-first-letter(rest)
    }

    (letter, rest)
  } else {
    // First letter already given.
    (text-args.pos().first(), body)
  }

  if transform != none {
    letter = transform(letter)
  }

  // Sample content for height of given amount of lines.
  let letter-height = if type(height) == int {
    let sample-lines = range(height).map(_ => [x]).join(linebreak())
    measure(sample-lines, styles).height
  } else {
    measure(v(height), styles).height
  }

  // Create dropcap with the height of sample content.
  let letter = sized(letter-height, letter, ..text-args.named())
  let letter-width = measure(letter, styles).width

  // Resolve overhang if given as percentage.
  let overhang = if type(overhang) == ratio {
    letter-width * overhang
  } else if type(overhang) == relative {
    letter-width * overhang.ratio + overhang.length
  } else {
    overhang
  }

  // Try to justify as many words as possible next to dropcap.
  let bounded = box.with(width: bounds.width - letter-width - gap + overhang)

  let index = 1
  let (first, second) = while true {
    let (first, second) = split(rest, index)
    let first = {
      set par(hanging-indent: hanging-indent, justify: justify)
      first
    }

    if second == none {
      // All content fits next to dropcap.
      (first, none)
      break
    }

    // Allow a bit more space to accommodate for larger elements.
    let max-height = letter-height + measure([x], styles).height / 2
    let height = measure(bounded(first), styles).height    
    if height > max-height {
      split(rest, index - 1)
      break
    }

    index += 1
  }

  // Layout dropcap and aside text as grid.
  set par(justify: justify)

  box(grid(
    column-gutter: gap,
    columns: (letter-width - overhang, 1fr),
    move(dx: -overhang, letter),
    {
      set par(hanging-indent: hanging-indent)
      first
      if second != none { linebreak(justify: justify) }
    }
  ))

  linebreak()
  second
}))
