I felt inspired by seeing this [Quick Journal](https://apps.apple.com/gb/app/quick-journal-just-write/id6554003659) app and [Raphael Schaad’s Config 2024 talk](https://youtu.be/NCgGs3d2SF4?feature=shared&t=887) - particularly the image of a grid of scanned notebook pages in Figma:

![](./Images/raphael_shaad_figma_fieldnotes.png)

Decided to finally try and create the simple notebook app that I’ve been wanting for ages.

- 2D grid of fixed-size dot grid pages. Navigate between them by swiping.
- A PencilKit experience without all the fiddly parts
- Only pencil input
- Map view which shows all pages
- No page zooming, content ignores device rotation 

The first sketch in Apple Notes:

![](./Images/gridnotes-first-sketch.jpeg)

# Branches

- main: personal notes and sketches
- notebooks/work-notes: work notes and sketches
- dev: stuff for dev and testing which I don’t mind losing

Each branch has a custom Bundle ID and Display Name to keep their data separate on iPadOS. This is good enough until I have time to add simple enough in-app notebook selection.
