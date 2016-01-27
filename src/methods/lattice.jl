using QuantJulia.Time

type TreeLattice1D{T, I <: Integer} <: TreeLattice
  tg::TimeGrid
  impl::T
  statePrices::Vector{Vector{Float64}}
  n::I
  statePricesLimit::I
end

function TreeLattice1D{I <: Integer, T}(tg::TimeGrid, n::I, impl::T)
  statePrices = Vector{Vector{Float64}}(1)
  statePrices[1] = ones(1)

  statePricesLimit = 1

  return TreeLattice1D(tg, impl, statePrices, n, statePricesLimit)
end

function get_state_prices!(t::TreeLattice1D, i::Int)
  if i > t.statePricesLimit
    compute_state_prices!(t, i)
  end

  return t.statePrices[i]
end

function compute_state_prices!(t::TreeLattice1D, until::Int)
  for i = t.statePricesLimit:until - 1
    push!(t.statePrices, zeros(get_size(t.impl, i + 1)))
    for j = 1:get_size(t.impl, i)
      disc = discount(t.impl, i, j)
      statePrice = t.statePrices[i][j]
      for l = 1:t.n
        t.statePrices[i + 1][descendant(t.impl, i, j, l)] += statePrice * disc * probability(t.impl, i, j, l)
      end
    end
  end

  t.statePricesLimit = until

  return t
end

type Branching{I <: Integer}
  k::Vector{I}
  probs::Vector{Vector{Float64}}
  kMin::I
  jMin::I
  kMax::I
  jMax::I
end

function Branching()
  probs = Vector{Vector{Float64}}(3)
  probs[1] = zeros(0)
  probs[2] = zeros(0)
  probs[3] = zeros(0)
  return Branching(zeros(Int, 0), probs, typemax(Int), typemax(Int), typemin(Int), typemin(Int))
end

get_size(b::Branching) = b.jMax - b.jMin + 1

function add!(branch::Branching, k::Int, p1::Float64, p2::Float64, p3::Float64)
  push!(branch.k, k)
  push!(branch.probs[1], p1)
  push!(branch.probs[2], p2)
  push!(branch.probs[3], p3)

  # maintain invariants
  branch.kMin = min(branch.kMin, k)
  branch.jMin = branch.kMin - 1
  branch.kMax = max(branch.kMax, k)
  branch.jMax = branch.kMax + 1

  return branch
end

descendant(b::Branching, idx::Int, branch::Int) = b.k[idx] - b.jMin - 1 + branch

probability(b::Branching, idx::Int, branch::Int) = b.probs[branch][idx]

type TrinomialTree{S <: StochasticProcess}
  process::S
  timeGrid::TimeGrid
  dx::Vector{Float64}
  branchings::Vector{Branching}
  isPositive::Bool
end

function TrinomialTree{S <: StochasticProcess}(process::S, timeGrid::TimeGrid, isPositive::Bool = false)
  x0 = process.x0
  dx = zeros(length(timeGrid.times))
  nTimeSteps = length(timeGrid.times) - 1
  jMin = 0
  jMax = 0
  branchings = Vector{Branching}(nTimeSteps)

  for i = 1:nTimeSteps
    t = timeGrid.times[i]
    dt = timeGrid.dt[i]

    # Variance must be independent of x
    v2 = variance(process, t, 0.0, dt)
    v = sqrt(v2)
    dx[i+1] = v * sqrt(3.0)

    branching = Branching()

    for j =jMin:jMax
      x = x0 + j * dx[i]
      m = expectation(process, t, x, dt)
      temp = round(Int, floor((m - x0) / dx[i+1] + 0.5))

      if isPositive
        while (x0 + (temp - 1) * dx[i + 1] <= 0)
          temp += 1
        end
      end

      e = m - (x0 + temp * dx[i + 1])
      e2 = e * e
      e3 = e * sqrt(3.0)

      p1 = (1.0 + e2 / v2 - e3 / v) / 6.0
      p2 = (2.0 - e2 / v2) / 3.0
      p3 = (1.0 + e2 / v2 + e3 / v) / 6.0

      add!(branching, temp, p1, p2, p3)
    end

    branchings[i] = branching # check if we need copy

    jMin = branching.jMin
    jMax = branching.jMax
  end

  return TrinomialTree(process, timeGrid, dx, branchings, isPositive)
end

get_size{I <: Integer}(t::TrinomialTree, i::I) = i == 1 ? 1 : get_size(t.branchings[i-1])
function get_underlying(t::TrinomialTree, i::Int, idx::Int)
  if i == 1
    return t.process.x0
  else
    return t.process.x0 + (t.branchings[i - 1].jMin + (idx - 1) * t.dx[i])
  end
end

descendant(t::TrinomialTree, i::Int, idx::Int, branch::Int) = descendant(t.branchings[i], idx, branch)

probability(t::TrinomialTree, i::Int, j::Int, b::Int) = probability(t.branchings[i], j, b)
