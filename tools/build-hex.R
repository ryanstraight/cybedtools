# tools/build-hex.R
#
# Generates the hex sticker for cybedtools. Run from package root with:
#   Rscript tools/build-hex.R
#
# Output: man/figures/logo.png (and a higher-resolution copy at
# tools/cybedtools-hex@2x.png for slide decks / posters; the high-res
# copy is gitignored).

suppressPackageStartupMessages({
  library(hexSticker)
  library(ggplot2)
  library(ggraph)
  library(igraph)
  library(showtext)
})

# Use Google Font as the package title's typeface. Inter is clean,
# slightly technical, reads well at small sizes.
sysfonts::font_add_google("Inter", "inter")
sysfonts::font_add_google("JetBrains Mono", "jet")
showtext::showtext_auto()

# Three-node mini graph evoking the cybed: schema:
#   Framework -> Role -> Element
# Plotted with ggraph, baked into the hex via subplot.
nodes <- data.frame(
  id    = 1:3,
  label = c("F", "R", "E"),  # Framework, Role, Element
  x     = c(0.0, 0.6, 1.2),
  y     = c(0.6, 0.0, 0.6)
)
edges <- data.frame(
  from = c(1, 2),
  to   = c(2, 3),
  label = c("hasRole", "hasElement")
)
g <- igraph::graph_from_data_frame(edges, vertices = nodes, directed = TRUE)

graph_plot <- ggraph(g, layout = "manual", x = nodes$x, y = nodes$y) +
  geom_edge_link(
    arrow      = arrow(length = unit(2.5, "mm"), type = "closed"),
    end_cap    = circle(3.2, "mm"),
    start_cap  = circle(3.2, "mm"),
    edge_colour = "#7DD3FC",  # sky-300
    edge_width  = 0.8
  ) +
  geom_node_circle(
    aes(r = 0.18),
    fill = "#1E293B",
    color = "#7DD3FC",
    size = 0.6
  ) +
  geom_node_text(
    aes(label = label),
    family = "inter",
    fontface = "bold",
    color = "#E0F2FE",
    size = 5
  ) +
  coord_fixed(clip = "off") +
  theme_void() +
  theme(plot.background = element_rect(fill = NA, color = NA))

# Hex sticker
sticker_path <- "man/figures/logo.png"
dir.create(dirname(sticker_path), showWarnings = FALSE, recursive = TRUE)

sticker(
  subplot     = graph_plot,
  package     = "cybedtools",
  p_size      = 22,
  p_family    = "jet",          # monospaced for the package name
  p_color     = "#E0F2FE",       # sky-100
  p_y         = 1.45,
  s_x         = 1.0,
  s_y         = 0.85,
  s_width     = 1.5,
  s_height    = 1.5,
  h_fill      = "#0F172A",       # slate-900
  h_color     = "#38BDF8",       # sky-400
  h_size      = 1.4,
  url         = "w3id.org/cybed",
  u_color     = "#7DD3FC",
  u_size      = 5,
  u_family    = "jet",
  filename    = sticker_path,
  dpi         = 600
)

# Also save a higher-resolution copy for slides/posters.
sticker(
  subplot     = graph_plot,
  package     = "cybedtools",
  p_size      = 22,
  p_family    = "jet",
  p_color     = "#E0F2FE",
  p_y         = 1.45,
  s_x         = 1.0,
  s_y         = 0.85,
  s_width     = 1.5,
  s_height    = 1.5,
  h_fill      = "#0F172A",
  h_color     = "#38BDF8",
  h_size      = 1.4,
  url         = "w3id.org/cybed",
  u_color     = "#7DD3FC",
  u_size      = 5,
  u_family    = "jet",
  filename    = "tools/cybedtools-hex@2x.png",
  dpi         = 1200
)

message("Wrote: ", sticker_path)
message("Wrote: tools/cybedtools-hex@2x.png")
