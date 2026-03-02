---
layout: post
title: "Nassi-Shneiderman Diagrams: A Complete Guide to Structograms"
date: 2026-02-27 18:00 +0100
categories: [Software Engineering, Documentation]
tags: [nassi-shneiderman, structogram, flowchart, software-design, structured-programming, diagrams]
description: A comprehensive guide to Nassi-Shneiderman diagrams (structograms), covering their history, full legend of symbols, how to create them, and best practices for clear algorithm visualization.
---

# Nassi-Shneiderman Diagrams: A Complete Guide to Structograms

Nassi-Shneiderman diagrams (NSDs), also called **structograms**, are a graphical notation for structured programming. Unlike traditional flowcharts that can easily produce unstructured "spaghetti" flows with arbitrary jumps, structograms enforce a disciplined, top-down design that maps directly to code constructs like sequences, branches, and loops. They were introduced by **Isaac Nassi** and **Ben Shneiderman** in 1973 and are standardized in **DIN 66261** and **ISO 5807**.

## Why Structograms?

Traditional flowcharts have a fundamental problem: they allow arbitrary control flow through unrestricted use of arrows and `GOTO`-style jumps. This makes it easy to draw diagrams that represent poorly structured, hard-to-maintain code. Nassi and Shneiderman designed their notation specifically to make unstructured control flow **impossible to express**. Every diagram element nests inside its parent, enforcing the hierarchical structure that Edsger Dijkstra and the structured programming movement advocated.

Key advantages:

- **No arbitrary jumps** -- the notation physically cannot represent `GOTO` or spaghetti logic.
- **Direct code mapping** -- each symbol corresponds to a programming construct (sequence, if/else, while, etc.).
- **Readable top-to-bottom** -- execution flows strictly from the top of the diagram to the bottom.
- **Compact** -- structograms use space efficiently compared to flowcharts with their many arrows and decision diamonds.
- **Nesting is visible** -- the depth of nested constructs is immediately apparent from the diagram structure.

## The Complete Legend

A Nassi-Shneiderman diagram is built from a small set of standardized symbols. Each symbol represents exactly one structured programming construct. The symbols are stacked vertically and nested inside one another to form complete algorithms.

### 1. Process Block (Action / Statement)

The most basic element is a simple rectangle containing a single instruction or action.

```
┌─────────────────────────┐
│   action / statement    │
└─────────────────────────┘
```

**Usage:** Any single operation -- an assignment, a function call, an I/O operation, or any atomic step. Multiple process blocks stacked vertically form a **sequence**.

### 2. Sequence

A sequence is a series of process blocks executed one after another, from top to bottom.

```
┌─────────────────────────┐
│   Step 1                │
├─────────────────────────┤
│   Step 2                │
├─────────────────────────┤
│   Step 3                │
└─────────────────────────┘
```

**Usage:** Represents sequential execution. This is the default composition -- any structogram is a sequence of blocks at its outermost level.

### 3. Selection (If-Then-Else / Branching)

A branching construct divides the block with diagonal lines from the top corners meeting at a point, forming two regions: one for the **true** (yes) branch and one for the **false** (no) branch. The condition is written in the triangular area at the top.

```
┌─────────────────────────┐
│ \     condition?      / │
│   \       ↓         /   │
│ Yes \             / No  │
├───────┐         ┌───────┤
│       │         │       │
│ action│         │ action│
│  (T)  │         │  (F)  │
│       │         │       │
└───────┴─────────┴───────┘
```

**Usage:** Represents `if-then-else`. If one branch has no action, it is left empty (this models a plain `if-then` without an `else`).

### 4. Multiple Selection (Case / Switch)

For more than two alternatives, the case construct fans out from a single condition into multiple branches.

```
┌─────────────────────────────────────┐
│          condition / variable       │
├──────────┬──────────┬───────────────┤
│  Case 1  │  Case 2  │   Default    │
├──────────┼──────────┼───────────────┤
│ action 1 │ action 2 │ default      │
│          │          │ action       │
└──────────┴──────────┴───────────────┘
```

**Usage:** Represents a `switch/case` or `match` statement. Each column corresponds to one case value. An optional default/else column handles all unmatched values.

### 5. While Loop (Pre-Tested / Test-First)

A loop with the condition tested **before** each iteration. The loop body is indented to the right, with a vertical bar on the left indicating the loop boundary.

```
┌─────────────────────────┐
│ WHILE condition         │
│ ┌───────────────────────┤
│ │                       │
│ │   loop body           │
│ │                       │
│ └───────────────────────┤
└─────────────────────────┘
```

**Usage:** Represents `while (condition) { ... }`. If the condition is false initially, the body is never executed.

### 6. Do-While Loop (Post-Tested / Test-Last)

A loop with the condition tested **after** each iteration. The loop body appears first, with the condition at the bottom.

```
┌─────────────────────────┐
├───────────────────────┐ │
│                       │ │
│   loop body           │ │
│                       │ │
├───────────────────────┘ │
│ UNTIL condition         │
└─────────────────────────┘
```

**Usage:** Represents `do { ... } while (condition)`. The body always executes at least once.

### 7. Parallel Execution

Parallel blocks are placed side-by-side within a shared boundary, separated by vertical dashed or solid lines, with horizontal markers at the fork and join points.

```
┌─────────────────────────────┐
│ ══════ PARALLEL ══════      │
├──────────────┬──────────────┤
│  Process A   │  Process B   │
├──────────────┴──────────────┤
│ ══════ END PARALLEL ══════  │
└─────────────────────────────┘
```

**Usage:** Represents concurrent or parallel execution of independent tasks. Less commonly used than the other elements, but defined in the notation.

### 8. Procedure / Function Call

A process block with vertical side-bars indicates a call to a separately defined subroutine or function.

```
┌──┬──────────────────────┬──┐
│  │  call subroutine()   │  │
└──┴──────────────────────┴──┘
```

**Usage:** Represents invoking a predefined function, method, or procedure. The subroutine itself can be documented in its own structogram.

### Legend Summary Table

| Symbol | Construct | Programming Equivalent |
|--------|-----------|----------------------|
| Simple rectangle | Process / Action | Single statement |
| Stacked rectangles | Sequence | Statement block `{ ... }` |
| Triangle + two columns | Selection | `if / else` |
| Multiple columns | Case / Switch | `switch / case / match` |
| Left-bar, condition on top | While loop | `while (cond) { }` |
| Right-bar, condition on bottom | Do-While loop | `do { } while (cond)` |
| Side-by-side blocks | Parallel execution | Threads / async tasks |
| Double-bordered rectangle | Procedure call | Function / method call |

## Example: Binary Search

Here is a practical example showing how a binary search algorithm looks as a structogram:

```
┌──────────────────────────────────────────────┐
│  low = 0                                     │
├──────────────────────────────────────────────┤
│  high = length(array) - 1                    │
├──────────────────────────────────────────────┤
│  result = -1                                 │
├──────────────────────────────────────────────┤
│ WHILE low <= high AND result == -1           │
│ ┌────────────────────────────────────────────┤
│ │  mid = (low + high) / 2                    │
│ ├────────────────────────────────────────────┤
│ │ \     array[mid] == target?             /  │
│ │   \              ↓                    /    │
│ │ Yes \                              / No    │
│ ├──────────────┬─────────────────────────────┤
│ │ result = mid │ \  array[mid] < target?  /  │
│ │              │   \        ↓           /    │
│ │              │ Yes \               / No    │
│ │              ├─────────────┬───────────────┤
│ │              │low = mid + 1│high = mid - 1 │
│ └──────────────┴─────────────┴───────────────┤
└──────────────────────────────────────────────┘
```

This diagram clearly shows the nested structure: a while loop containing a sequence with a two-level branching decision. In a traditional flowchart, the same algorithm would require several arrows crossing each other, making it harder to follow.

## How to Create Nassi-Shneiderman Diagrams

### By Hand

Structograms are straightforward to draw on paper or a whiteboard. Start with the outermost rectangle and work inward, adding constructs top-to-bottom. This makes them excellent for whiteboard design sessions and exams.

### Software Tools

Several tools support creating structograms digitally:

| Tool | Type | Notes |
|------|------|-------|
| [Structorizer](https://structorizer.fisch.lu/) | Desktop (Java) | Open-source, full NSD support, code export/import |
| [Struktog](https://dditools.inf.tu-dresden.de/struktog/) | Web-based | Free, browser-based editor |
| [draw.io / diagrams.net](https://app.diagrams.net/) | Web / Desktop | General diagramming with NSD shapes available |
| [Lucidchart](https://www.lucidchart.com/) | Web-based | Commercial, supports NSD via custom shapes |
| [PlantUML](https://plantuml.com/) | Text-based | Can approximate structograms with creole tables |
| LaTeX (`struktex` package) | Text-based | High-quality output for academic papers |

**Structorizer** deserves special mention. It is a free, open-source tool dedicated entirely to Nassi-Shneiderman diagrams. It can:

- Import code from languages like Java, C, C#, Python, and Pascal and generate the corresponding structogram.
- Export structograms to code in multiple languages.
- Export diagrams as PNG, SVG, or PDF.
- Step through the diagram interactively for educational use (the "Executor" feature).

### Creating a Structogram with Structorizer (Step-by-Step)

1. **Download and install** Structorizer from [structorizer.fisch.lu](https://structorizer.fisch.lu/).
2. **Create a new diagram** -- you start with a single empty process block.
3. **Add elements** using the toolbar or right-click context menu:
   - Click the instruction icon to add a process block.
   - Click the IF icon to add a selection.
   - Click the WHILE or REPEAT icon to add loops.
   - Click the CALL icon to add a subroutine call.
   - Click the CASE icon to add a multiple selection.
4. **Edit text** by double-clicking any element to set its content.
5. **Nest elements** by selecting a parent element first, then inserting a child element inside it.
6. **Export** the finished diagram via `File → Export` as an image or source code.

### Creating a Structogram with LaTeX

For academic papers and formal documentation, the `struktex` LaTeX package produces publication-quality structograms:

```latex
\documentclass{article}
\usepackage{struktex}

\begin{document}

\begin{struktogramm}(100,60)[Factorial]
  \assign{result := 1}
  \assign{i := 1}
  \while{i <= n}
    \assign{result := result * i}
    \assign{i := i + 1}
  \whilealiend
  \assign{return result}
\end{struktogramm}

\end{document}
```

## Best Practices

### 1. Keep Diagrams Focused

Each structogram should represent **one function or algorithm**. If a diagram grows beyond a single page or screen, break it into sub-diagrams using procedure call blocks. A structogram that tries to capture an entire program becomes unreadable.

### 2. Use Meaningful Descriptions

Write clear, concise text in each block. Avoid implementation-level syntax like `i++` -- prefer natural-language descriptions like "increment counter" or pseudo-code that readers from different language backgrounds can understand. The goal is to communicate the algorithm, not to write compilable code.

### 3. Limit Nesting Depth

Deeply nested structures (more than 3-4 levels) become hard to read even in a structogram. If your diagram has excessive nesting, consider refactoring the algorithm:

- Extract inner logic into a separate subroutine (and use a procedure call block).
- Simplify conditions using guard clauses or early returns.
- Use a case/switch instead of cascaded if-else chains.

### 4. Be Consistent with Granularity

Decide on a consistent level of detail. Do not mix high-level descriptions ("validate user input") with low-level operations ("set `isValid` flag to `false`") in the same diagram. If both levels are needed, use a high-level structogram with procedure calls that link to detailed sub-diagrams.

### 5. Start Top-Down

Design your structogram from the top (the overall flow) and progressively refine each block. This mirrors the top-down design philosophy that structograms were created to support. Sketch the main sequence first, then expand each step.

### 6. Label Branches Clearly

In selection blocks, always label both the true and false branches explicitly (e.g., "Yes" / "No", or the specific condition values). For case/switch blocks, list all expected values and always include a default case to handle unexpected input.

### 7. Validate Against Code

If you are documenting existing code, verify that the structogram matches the actual implementation. Structorizer's code import feature is invaluable for this -- import the code and compare the generated diagram with your hand-drawn version.

### 8. Use Structograms at the Right Stage

Structograms are most useful during:

- **Algorithm design** -- before writing code, to think through the logic.
- **Code reviews** -- to visualize and discuss complex control flow.
- **Education** -- to teach programming constructs and structured thinking.
- **Documentation** -- for algorithms that are critical or complex enough to warrant a visual explanation.

They are less useful for high-level system architecture (use UML component or sequence diagrams instead) or for trivial CRUD operations where the diagram would add no value.

### 9. Prefer Structograms Over Flowcharts for Structured Code

If your code follows structured programming principles (no `GOTO`, no arbitrary jumps), structograms are strictly superior to flowcharts because they enforce and visualize that structure. Reserve flowcharts for cases where you genuinely need to represent unstructured or interrupt-driven control flow.

### 10. Version Control Your Diagrams

Treat structograms as part of your project's documentation. If you use a text-based tool (LaTeX `struktex`, Structorizer's XML format), store the source files alongside your code in version control. This ensures diagrams stay in sync with code changes and benefit from the same review process.

## Common Mistakes to Avoid

- **Mixing structogram and flowchart notation** -- do not add arrows or decision diamonds inside a structogram. The notation is self-contained.
- **Forgetting the else branch** -- even if the else branch is empty, the selection block should still show both sides. Leave the empty side blank rather than omitting it.
- **Overloading a single diagram** -- a structogram for a 200-line function will be unreadable. Decompose first.
- **Using structograms for concurrent/event-driven systems** -- structograms model sequential, structured control flow. For event-driven architectures, state machines or sequence diagrams are more appropriate.

## Conclusion

Nassi-Shneiderman diagrams remain a valuable tool for designing and documenting algorithms. Their enforced structure eliminates the chaos of arbitrary control flow, their compact notation saves space, and their direct mapping to code constructs makes them practical for both design and documentation. Whether you are a student learning programming fundamentals or an engineer documenting a critical algorithm, structograms offer clarity that flowcharts cannot match.

## References

- Nassi, I. & Shneiderman, B. (1973). *Flowchart Techniques for Structured Programming*. ACM SIGPLAN Notices, 8(8), 12-26.
- [DIN 66261 -- Nassi-Shneiderman Diagrams](https://www.dinmedia.de/en/standard/din-66261/1365422)
- [Structorizer -- Free NSD Editor](https://structorizer.fisch.lu/)
- [Struktog -- Web-based Structogram Editor](https://dditools.inf.tu-dresden.de/struktog/)
- [LaTeX struktex Package](https://ctan.org/pkg/struktex)
- [Wikipedia -- Nassi-Shneiderman Diagram](https://en.wikipedia.org/wiki/Nassi%E2%80%93Shneiderman_diagram)
