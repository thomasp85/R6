#' Create an R6 reference object generator
#'
#' R6 objects are essentially environments, structured in a way that makes them
#' look like an object in a more typical object-oriented language than R. They
#' support public and private members, as well as inheritance across different
#' packages.
#'
#' An R6 object consists of a public environment, and may also contain a private
#' environment, as well as environments for superclasses. In one sense, the
#' object and the public environment are the same; a reference to the object is
#' identical to a reference to the public environment. But in another sense, the
#' object also consists of the fields, methods, private environment and so on.
#'
#' The \code{active} argument is a list of active binding functions. These
#' functions take one argument. They look like regular variables, but when
#' accessed, a function is called with an optional argument. For example, if
#' \code{obj$x2} is an active binding, then when accessed as \code{obj$x2}, it
#' calls the \code{x2()} function that was in the \code{active} list, with no
#' arguments. However, if a value is assigned to it, as in \code{obj$x2 <- 50},
#' then the function is called with the right-side value as its argument, as in
#' \code{x2(50)}. See \code{\link{makeActiveBinding}} for more information.
#'
#' If the public or private lists contain any items that have reference
#' semantics (for example, an environment), those items will be shared across
#' all instances of the class. To avoid this, add an entry for that item with a
#' \code{NULL} initial value, and then in the \code{intialize} method,
#' instantiate the object and assign it.
#'
#' @section The \code{print} method:
#'
#'   R6 object generators and R6 objects have a default \code{print} method to
#'   show them on the screen: they simply list the members and parameters (e.g.
#'   lock, portable, etc., see above) of the object.
#'
#'   The default \code{print} method of R6 objects can be redefined, by
#'   supplying a public \code{print} method. (\code{print} members that are not
#'   functions are ignored.) This method is automatically called whenever the
#'   object is printed, e.g. when the object's name is typed at the command
#'   prompt, or when \code{print(obj)} is called. It can also be called directly
#'   via \code{obj$print()}. All extra arguments from a \code{print(obj, ...)}
#'   call are passed on to the \code{obj$print(...)} method.
#'
#' @section Portable and non-portable classes:
#'
#'   When R6 classes are portable (the default), they can be inherited across
#'   packages without complication. However, when in portable mode, members must
#'   be accessed with \code{self} and \code{private}, as in \code{self$x} and
#'   \code{private$y}.
#'
#'   When used in non-portable mode, R6 classes behave more like reference
#'   classes: inheritance across packages will not work well, and \code{self}
#'   and \code{private} are not necessary for accessing fields.
#'
#' @section S3 details:
#'
#'   Normally the public environment will have two classes: the one supplied in
#'   the \code{classname} argument, and \code{"R6"}. It is possible to get the
#'   public environment with no classes, by using \code{class=FALSE}. This will
#'   result in faster access speeds by avoiding class-based dispatch of
#'   \code{$}. The benefit is is negligible in most cases.
#'
#'   If a class is a subclass of another, the object will have as its classes
#'   the \code{classname}, the superclass's \code{classname}, and \code{"R6"}
#'
#'   The primary difference in behavior when \code{class=FALSE} is that, without
#'   a class attribute, it won't be possible to use S3 methods with the objects.
#'   So, for example, pretty printing (with \code{print.R6Class}) won't be used.
#'
#' @aliases R6
#' @export
#' @param classname Name of the class. The class name is useful primarily for S3
#'   method dispatch.
#' @param public A list of public members, which can be functions (methods) and
#'   non-functions (fields).
#' @param private An optional list of private members, which can be functions
#'   and non-functions.
#' @param active An optional list of active binding functions.
#' @param inherit A R6ClassGenerator object to inherit from; in other words, a
#'   superclass. This is captured as an unevaluated expression which is
#'   evaluated in \code{parent_env} each time an object is instantiated.
#' @param portable If \code{TRUE} (the default), this class will work with
#'   inheritance across different packages. Note that when this is enabled,
#'   fields and members must be accessed with  \code{self$x} or
#'   \code{private$x}; they can't be accessed with just \code{x}.
#' @param parent_env An environment to use as the parent of newly-created
#'   objects.
#' @param class Should a class attribute be added to the object? Default is
#'   \code{TRUE}. If \code{FALSE}, the objects will simply look like
#'   environments, which is what they are.
#' @param lock Should the environments of the generated objects be locked? If
#'   locked, new members can't be added to the objects.
#' @examples
#' # A queue ---------------------------------------------------------
#' Queue <- R6Class("Queue",
#'   public = list(
#'     initialize = function(...) {
#'       for (item in list(...)) {
#'         self$add(item)
#'       }
#'     },
#'     add = function(x) {
#'       private$queue <- c(private$queue, list(x))
#'       invisible(self)
#'     },
#'     remove = function() {
#'       if (private$length() == 0) return(NULL)
#'       # Can use private$queue for explicit access
#'       head <- private$queue[[1]]
#'       private$queue <- private$queue[-1]
#'       head
#'     }
#'   ),
#'   private = list(
#'     queue = list(),
#'     length = function() base::length(private$queue)
#'   )
#' )
#'
#' q <- Queue$new(5, 6, "foo")
#'
#' # Add and remove items
#' q$add("something")
#' q$add("another thing")
#' q$add(17)
#' q$remove()
#' #> [1] 5
#' q$remove()
#' #> [1] 6
#'
#' # Private members can't be accessed directly
#' q$queue
#' #> NULL
#' # q$length()
#' #> Error: attempt to apply non-function
#'
#' # add() returns self, so it can be chained
#' q$add(10)$add(11)$add(12)
#'
#' # remove() returns the value removed, so it's not chainable
#' q$remove()
#' #> [1] "foo"
#' q$remove()
#' #> [1] "something"
#' q$remove()
#' #> [1] "another thing"
#' q$remove()
#' #> [1] 17
#'
#'
#' # Active bindings -------------------------------------------------
#' Numbers <- R6Class("Numbers",
#'   public = list(
#'     x = 100
#'   ),
#'   active = list(
#'     x2 = function(value) {
#'       if (missing(value)) return(self$x * 2)
#'       else self$x <- value/2
#'     },
#'     rand = function() rnorm(1)
#'   )
#' )
#'
#' n <- Numbers$new()
#' n$x
#' #> [1] 100
#' n$x2
#' #> [1] 200
#' n$x2 <- 1000
#' n$x
#' #> [1] 500
#'
#' # If the function takes no arguments, it's not possible to use it with <-:
#' n$rand
#' #> [1] 0.2648
#' n$rand
#' #> [1] 2.171
#' # n$rand <- 3
#' #> Error: unused argument (quote(3))
#'
#'
#' # Inheritance -----------------------------------------------------
#' # Note that this isn't very efficient - it's just for illustrating inheritance.
#' HistoryQueue <- R6Class("HistoryQueue",
#'   inherit = Queue,
#'   public = list(
#'     show = function() {
#'       cat("Next item is at index", private$head_idx + 1, "\n")
#'       for (i in seq_along(private$queue)) {
#'         cat(i, ": ", private$queue[[i]], "\n", sep = "")
#'       }
#'     },
#'     remove = function() {
#'       if (private$length() - private$head_idx == 0) return(NULL)
#'       private$head_idx <<- private$head_idx + 1
#'       private$queue[[private$head_idx]]
#'     }
#'   ),
#'   private = list(
#'     head_idx = 0
#'   )
#' )
#'
#' hq <- HistoryQueue$new(5, 6, "foo")
#' hq$show()
#' #> Next item is at index 1
#' #> 1: 5
#' #> 2: 6
#' #> 3: foo
#' hq$remove()
#' #> [1] 5
#' hq$show()
#' #> Next item is at index 2
#' #> 1: 5
#' #> 2: 6
#' #> 3: foo
#' hq$remove()
#' #> [1] 6
#'
#'
#'
#' # Calling superclass methods with super$ --------------------------
#' CountingQueue <- R6Class("CountingQueue",
#'   inherit = Queue,
#'   public = list(
#'     add = function(x) {
#'       private$total <<- private$total + 1
#'       super$add(x)
#'     },
#'     get_total = function() private$total
#'   ),
#'   private = list(
#'     total = 0
#'   )
#' )
#'
#' cq <- CountingQueue$new("x", "y")
#' cq$get_total()
#' #> [1] 2
#' cq$add("z")
#' cq$remove()
#' #> [1] "x"
#' cq$remove()
#' #> [1] "y"
#' cq$get_total()
#' #> [1] 3
#'
#' # Object copying --------------------------------------------------
#' # Shallow copying of R6 objects are provided for free using the copy
#' # method on class instances.
#'
#' Copier <- R6Class("Copier",
#'   public = list(
#'     x = 1
#'   )
#' )
#'
#' cop <- Copier$new()
#' cop2 <- cop
#' cop3 <- cop$copy()
#'
#' # cop and cop2 refers to the same object, while cop3 is disconnected
#' # from them both
#' cop$x <- 10
#'
#' cop$x == cop2$x
#' cop$x != cop3$x
#'
#' # More complicated objects with fields containing environments or other
#' # R6 objects might need additional handling if deep copying is wanted.
#'
#' DeepCopier <- R6Class("DeepCopier",
#'   public = list(
#'     y = Copier$new(),
#'     z = 'a'
#'   ),
#'   private = list(
#'     deepCopy = function() {
#'       list(
#'         public = list(y=self$y$copy())
#'       )
#'     }
#'   )
#' )
#'
#' dcop <- DeepCopier$new()
#' dcop2 <- dcop$copy()
#' dcop3 <- dcop$copy(deep = TRUE)
#'
#' # dcop2 is a shallow copy of dcop
#' dcop$z <- 'b'
#' dcop$z != dcop2$z
#'
#' dcop$y$x <- 10
#' dcop$y$x == dcop2$y$x
#'
#' # dcop3 is deep
#' dcop$y$x != dcop3$y$x
#'
#' # Non-portable classes --------------------------------------------
#' # By default, R6 classes are portable, which means they can be inherited
#' # across different packages. Portable classes require using self$ and
#' # private$ to access members.
#' # When used in non-portable mode, members can be accessed without self$,
#' # and assignments can be made with <<-.
#'
#' NP <- R6Class("NP",
#'   portable = FALSE,
#'   public = list(
#'     x = NA,
#'     getx = function() x,
#'     setx = function(value) x <<- value
#'   )
#' )
#'
#' np <- NP$new()
#' np$setx(10)
#' np$getx()
#' #> [1] 10
#'
#' # Setting new values ----------------------------------------------
#' # It is possible to add new members to the class after it has been created,
#' # by using the $set() method on the generator.
#'
#' Simple <- R6Class("Simple",
#'   public = list(
#'     x = 1,
#'     getx = function() self$x
#'   )
#' )
#'
#' Simple$set("public", "getx2", function() self$x*2)
#'
#' # Use overwrite = TRUE to overwrite existing values
#' Simple$set("public", "x", 10, overwrite = TRUE)
#'
#' s <- Simple$new()
#' s$x
#' s$getx2()
#'
#' # Debugging -------------------------------------------------------
#' \dontrun{
#' # This will enable debugging the getx() method for objects of the 'Simple'
#' # class that are instantiated in the future.
#' Simple$debug("getx")
#' s <- Simple$new()
#' s$getx()
#'
#' # Disable debugging for future instances:
#' Simple$undebug("getx")
#' s <- Simple$new()
#' s$getx()
#'
#' # To enable and disable debugging for a method in a single instance of an
#' # R6 object (this will not affect other objects):
#' s <- Simple$new()
#' debug(s$getx)
#' s$getx()
#' undebug(s$getx)
#' }
# This function is encapsulated so that it is bound in the R6 namespace, but
# enclosed in the capsule environment
R6Class <- encapsulate(function(classname = NULL, public = list(),
                                private = NULL, active = NULL,
                                inherit = NULL, lock = TRUE, class = TRUE,
                                portable = TRUE,
                                parent_env = parent.frame()) {

  if (!all_named(public) || !all_named(private) || !all_named(active))
    stop("All elements of public, private, and active must be named.")

  if (any(duplicated(c(names(public), names(private), names(active)))))
    stop("All items in public, private, and active must have unique names.")

  if (any(c("self", "private", "super") %in%
      c(names(public), names(private), names(active))))
    stop("Items cannot use reserved names 'self', 'private', and 'super'.")

  if ("initialize" %in% c(names(private), names(active)))
    stop("'initialize' is not allowed in private or active.")

  if (length(get_nonfunctions(active)) != 0)
    stop("All items in active must be functions.")


  # Create the generator object, which is an environment
  generator <- new.env(parent = capsule)

  generator$self <- generator

  generator$classname  <- classname
  generator$active     <- active
  generator$portable   <- portable
  generator$parent_env <- parent_env
  generator$lock       <- lock
  generator$class      <- class

  # Separate fields from methods
  generator$public_fields   <- get_nonfunctions(public)
  generator$private_fields  <- get_nonfunctions(private)
  generator$public_methods  <- get_functions(public)
  generator$private_methods <- get_functions(private)

  # Capture the unevaluated expression for the superclass; when evaluated in
  # the parent_env, it should return the superclass object.
  generator$inherit <- substitute(inherit)

  # Names of methods for which to enable debugging
  generator$debug_names <- character(0)

  # Set the generator functions to eval in the generator environment, and copy
  # them into the generator env.
  generator_funs <- assign_func_envs(generator_funs, generator)
  list2env2(generator_funs, generator)

  attr(generator, "name") <- paste0(classname, "_generator")
  class(generator) <- "R6ClassGenerator"

  generator
})
