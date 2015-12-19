# interpolation
abstract Interpolation

type LinearInterpolation <: Interpolation
  x_vals::Vector{Float64}
  y_vals::Vector{Float64}
  s::Vector{Float64}
end

# Log Linear interpolation
type LogInterpolation <: Interpolation
  x_vals::Vector{Float64}
  y_vals::Vector{Float64}
  interpolator::LinearInterpolation
end

function LogInterpolation(x_vals::Vector{Float64}, y_vals::Vector{Float64})
  # build log of y values, defaulting to 0 for initial state
  n = length(x_vals)
  log_y_vals = zeros(n)
  s = zeros(n) # first derivative

  # initialize the linear interpolator
  interpolator = LinearInterpolation(x_vals, log_y_vals, s)

  return LogInterpolation(x_vals, y_vals, interpolator)
end

# if no values are provided
function LogInterpolation()
  x_vals = Vector{Float64}()
  y_vals = Vector{Float64}()
  s = Vector{Float64}()

  interpolator = LinearInterpolation(x_vals, y_vals, s)

  return LogInterpolation(x_vals, y_vals, interpolator)
end

# Log initialize
function initialize!(interp::LogInterpolation, x_vals::Vector{Float64}, y_vals::Vector{Float64})
  interp.x_vals = x_vals
  interp.y_vals = y_vals

  log_y = zeros(length(y_vals))
  for i = 1:length(y_vals)
    @inbounds log_y[i] = log(i)
  end

  initialize!(interp.interpolator, x_vals, log_y)

  return interp
end

# Linear initialize
function initialize!(interp::LinearInterpolation, x_vals::Vector{Float64}, y_vals::Vector{Float64})
  interp.x_vals = x_vals
  interp.y_vals = y_vals
  interp.s = zeros(length(y_vals))

  return interp
end

# Log Interpolation update
function update!(interp::LogInterpolation, idx::Int64)
  # first get the log of the y values
  for i = 1:idx
    @inbounds interp.interpolator.y_vals[i] = log(interp.y_vals[i])
  end

  # use these log values to update the linear interpolator
  update!(interp.interpolator, idx)

  return interp
end

# update if value passed in
function update!(interp::LogInterpolation, idx::Int64, val::Float64)
  interp.y_vals[idx] = val

  update!(interp, idx)

  return interp
end

# Linear Interpolation update
function update!(interp::LinearInterpolation, idx::Int64)
  for i = 2:idx
    @inbounds dx = interp.x_vals[i] - interp.x_vals[i - 1]
    @inbounds interp.s[i - 1] = (interp.y_vals[i] - interp.y_vals[i - 1]) / dx
  end

  return interp
end

# locate x
function locate(interp::Interpolation, val::Float64)
  if val < interp.x_vals[1]
    return 1
  elseif val >= interp.x_vals[end]
    # return interp.x_vals[end] - interp.x_vals[1] - 2
    return length(interp.x_vals)
  else
    return findfirst(interp.x_vals .> val) - 1 # need to look at this
  end
end

value(interp::LogInterpolation, val::Float64) = exp(value(interp.interpolator, val))

function value(interp::LinearInterpolation, val::Float64)
  i = locate(interp, val)
  return interp.y_vals[i] + (val - interp.x_vals[i]) * interp.s[i]
end
