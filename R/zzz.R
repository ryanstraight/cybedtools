# Declare bare column-name variables used inside dplyr verbs so R CMD check
# does not flag them as undefined globals. These are dplyr data-mask names,
# not values from the package's namespace.
utils::globalVariables(c("s", "o"))
