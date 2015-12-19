# building fixed rate bonds
include("src/QuantJulia.jl")
using QuantJulia

function build_bonds(bond_mats, bond_rates, tenor, conv, rule, calendar, dc, freq, issue_date)
  bonds = Vector{FixedRateBond}(length(bond_mats))
  pricing_engine = DiscountingBondEngine()

  for i =1:length(bond_mats)
    term_date = bond_mats[i]
    # rate = bond_rates[i] / 100
    rate = bond_rates[i]
    sched = QuantJulia.Time.Schedule(issue_date, term_date, tenor, conv, conv, rule, true)
    bond = FixedRateBond(0, 100.0, sched, rate, dc, conv, 100.0, issue_date, calendar, pricing_engine)
    bonds[i] = bond
  end

  return bonds
end

function get_npvs(bonds, issue_date, calendar, dc, freq)
  pricing_engine = DiscountingBondEngine()
  rate_quote = Quote(0.05)
  compounding = CompoundedCompounding()
  yts = FlatForwardTermStructure(0, issue_date, calendar, rate_quote, dc, compounding, freq)
  npvs = zeros(length(bonds))
  for i=1:length(bonds)
    npvs[i] = calculate(pricing_engine, yts, bonds[i])
  end

  return npvs
end

function par_rate(yts::YieldTermStructure, dates::Vector{Date}, dc::QuantJulia.Time.DayCount)
  sum = 0.0
  for i = 2:length(dates)
    dt = QuantJulia.Time.year_fraction(dc, dates[i - 1], dates[i])
    sum += discount(yts, dates[i]) * dt
  end

  result = discount(yts, dates[1]) - discount(yts, dates[end])
  return result/sum
end

function setup()
  today = now()
  issue_date = Date(Dates.Year(today), Dates.Month(today), Dates.Day(today))
  bond_mats = [issue_date + Dates.Year(i) for i in range(2, 2, 15)]
  # bond_rates = [5.75, 6.0, 6.25, 6.5, 6.75, 6.80, 7.00, 7.1, 7.15, 7.2]
  bond_rates = [0.0200, 0.0225, 0.0250, 0.0275, 0.0300, 0.0325, 0.0350, 0.0375, 0.0400, 0.0425, 0.0450, 0.0475, 0.0500, 0.0525, 0.0550]
  set_eval_date!(settings, issue_date)

  freq = QuantJulia.Time.Annual()
  tenor = QuantJulia.Time.TenorPeriod(freq)
  conv = QuantJulia.Time.Unadjusted()
  rule = QuantJulia.Time.DateGenerationBackwards()
  calendar = QuantJulia.Time.USGovernmentBondCalendar()
  dc = QuantJulia.Time.SimpleDayCount()
  bonds = build_bonds(bond_mats, bond_rates, tenor, conv, rule, calendar, dc, freq, issue_date)

  return issue_date, bonds, dc, calendar
end

function piecewise_yld_curve()
  issue_date, bonds, dc, calendar = setup()

  interp = QuantJulia.Math.LogInterpolation()
  trait = Discount()
  bootstrap = IterativeBootstrap()

  yts = PiecewiseYieldCurve(issue_date, bonds, dc, interp, trait, 0.00000000001, bootstrap)

  solver = QuantJulia.Math.BrentSolver()
  solver2 = QuantJulia.Math.FiniteDifferenceNewtonSafe()
  calculate!(IterativeBootstrap(), yts, solver2, solver)

  # println(yts.data)

  for bond in bonds
    date_vec = Vector{Date}(length(bond.cashflows.coupons) + 1)
    date_vec[1] = issue_date
    for (i, cf) in enumerate(bond.cashflows.coupons)
      date_vec[i+1] = date(cf)
    end
    par = par_rate(yts, date_vec, dc)
    println(100.0 * par)
  end
end


  # npvs = get_npvs(bonds, issue_date, calendar, dc, freq)
function fitted_bond_curve_exp()
  issue_date, bonds, dc, calendar = setup()

  esf = ExponentialSplinesFitting(true, length(bonds))
  fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, esf, 1e-10, 5000, 1.0)
  initialize!(fitted_curve)
  calculate!(fitted_curve)

  # println(fitted_curve.fittingMethod.minimumCostValue)
  println(fitted_curve.fittingMethod.commons.numberOfIterations)
  # println(fitted_curve.fittingMethod.guessSolution)

  disc = discount(fitted_curve, 1.0)
  println(disc)
end

function fitted_bond_curve_simp()
  issue_date, bonds, dc, calendar = setup()

  spf = SimplePolynomialFitting(true, 3, length(bonds))
  fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, spf, 1e-10, 5000, 1.0)
  initialize!(fitted_curve)
  calculate!(fitted_curve)

  # println(fitted_curve.fittingMethod.minimumCostValue)
  println(fitted_curve.fittingMethod.commons.numberOfIterations)
  # println(fitted_curve.fittingMethod.guessSolution)

  disc = discount(fitted_curve, 1.0)
  println(disc)
end

function fitted_bond_curve_ns()
  issue_date, bonds, dc, calendar = setup()

  nsf = NelsonSiegelFitting(length(bonds))
  fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, nsf, 1e-10, 5000, 1.0)
  initialize!(fitted_curve)
  calculate!(fitted_curve)

  # println(fitted_curve.fittingMethod.minimumCostValue)
  println(fitted_curve.fittingMethod.commons.numberOfIterations)
  # println(fitted_curve.fittingMethod.guessSolution)

  disc = discount(fitted_curve, 1.0)
  println(disc)
end

function fitted_bond_curve_sven()
  issue_date, bonds, dc, calendar = setup()

  sf = SvenssonFitting(length(bonds))
  fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, sf, 1e-10, 5000, 1.0)
  initialize!(fitted_curve)
  calculate!(fitted_curve)

  # println(fitted_curve.fittingMethod.minimumCostValue)
  println(fitted_curve.fittingMethod.commons.numberOfIterations)
  # println(fitted_curve.fittingMethod.guessSolution)

  disc = discount(fitted_curve, 1.0)
  println(disc)
end

function fitted_bond_curve_cbspline()
  issue_date, bonds, dc, calendar = setup()

  knots = [-30.0, -20.0, 0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0]
  cbsf = CubicBSplinesFitting(true, knots, length(bonds))
  fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, cbsf, 1e-10, 5000, 1.0)
  initialize!(fitted_curve)
  calculate!(fitted_curve)

  println(fitted_curve.fittingMethod.commons.numberOfIterations)
  disc = discount(fitted_curve, 1.0)
  println(disc)
end

function fitted_bond_curve_all()
  tic()
  issue_date, bonds, dc, calendar = setup()

  esf = ExponentialSplinesFitting(true, length(bonds))
  esf_fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, esf, 1e-10, 5000, 1.0)
  initialize!(esf_fitted_curve)
  calculate!(esf_fitted_curve)

  spf = SimplePolynomialFitting(true, 3, length(bonds))
  spf_fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, spf, 1e-10, 5000, 1.0)
  initialize!(spf_fitted_curve)
  calculate!(spf_fitted_curve)

  nsf = NelsonSiegelFitting(length(bonds))
  nsf_fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, nsf, 1e-10, 5000, 1.0)
  initialize!(nsf_fitted_curve)
  calculate!(nsf_fitted_curve)

  knots = [-30.0, -20.0, 0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0]
  cbsf = CubicBSplinesFitting(true, knots, length(bonds))
  cbsf_fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, cbsf, 1e-10, 5000, 1.0)
  initialize!(cbsf_fitted_curve)
  calculate!(cbsf_fitted_curve)

  sf = SvenssonFitting(length(bonds))
  sf_fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, sf, 1e-10, 5000, 1.0)
  initialize!(sf_fitted_curve)
  calculate!(sf_fitted_curve)
  toc()

  println("Exponential Splines: $(esf_fitted_curve.fittingMethod.commons.numberOfIterations)")
  println("Simple Polynomial: $(spf_fitted_curve.fittingMethod.commons.numberOfIterations)")
  println("Nelson Siegel: $(nsf_fitted_curve.fittingMethod.commons.numberOfIterations)")
  println("Cubic B-Splines: $(cbsf_fitted_curve.fittingMethod.commons.numberOfIterations)")
  println("Svensson Fitting: $(sf_fitted_curve.fittingMethod.commons.numberOfIterations)")
end

function main()
  issue_date, bonds, dc, calendar = setup()

  println("Today's date: $issue_date")
  println("Calculating fit for 15 bonds....")

  interp = QuantJulia.Math.LogInterpolation()
  trait = Discount()
  bootstrap = IterativeBootstrap()

  yts = PiecewiseYieldCurve(issue_date, bonds, dc, interp, trait, 0.00000000001, bootstrap)

  solver = QuantJulia.Math.BrentSolver()
  solver2 = QuantJulia.Math.FiniteDifferenceNewtonSafe()
  calculate!(IterativeBootstrap(), yts, solver2, solver)

  esf = ExponentialSplinesFitting(true, length(bonds))
  esf_fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, esf, 1e-10, 5000, 1.0)
  initialize!(esf_fitted_curve)
  calculate!(esf_fitted_curve)

  println("(a) exponential splines")
  println("reference date : ", esf_fitted_curve.referenceDate)
  println("number of iterations : ", esf_fitted_curve.fittingMethod.commons.numberOfIterations)

  spf = SimplePolynomialFitting(true, 3, length(bonds))
  spf_fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, spf, 1e-10, 5000, 1.0)
  initialize!(spf_fitted_curve)
  calculate!(spf_fitted_curve)

  println("(b) simple polynomial")
  println("reference date : ", spf_fitted_curve.referenceDate)
  println("number of iterations : ", spf_fitted_curve.fittingMethod.commons.numberOfIterations)

  nsf = NelsonSiegelFitting(length(bonds))
  nsf_fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, nsf, 1e-10, 5000, 1.0)
  initialize!(nsf_fitted_curve)
  calculate!(nsf_fitted_curve)

  println("(c) Nelson-Siegel")
  println("reference date : ", nsf_fitted_curve.referenceDate)
  println("number of iterations : ", nsf_fitted_curve.fittingMethod.commons.numberOfIterations)

  knots = [-30.0, -20.0, 0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0]
  cbsf = CubicBSplinesFitting(true, knots, length(bonds))
  cbsf_fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, cbsf, 1e-10, 5000, 1.0)
  initialize!(cbsf_fitted_curve)
  calculate!(cbsf_fitted_curve)

  println("(d) cubic B-splines")
  println("reference date : ", cbsf_fitted_curve.referenceDate)
  println("number of iterations : ", cbsf_fitted_curve.fittingMethod.commons.numberOfIterations)

  sf = SvenssonFitting(length(bonds))
  sf_fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, sf, 1e-10, 5000, 1.0)
  initialize!(sf_fitted_curve)
  calculate!(sf_fitted_curve)

  println("(e) Svensson")
  println("reference date : ", sf_fitted_curve.referenceDate)
  println("number of iterations : ", sf_fitted_curve.fittingMethod.commons.numberOfIterations)

  println("Output par rates for each curve.  In this case, par rates should equal coupons for these par bonds")

  println(" tenor | coupon | bstrap |  (a)  |  (b)  |  (c)  |  (d)  |  (e)  ")

  for bond in bonds
    date_vec = Vector{Date}(length(bond.cashflows.coupons) + 1)
    date_vec[1] = issue_date
    for (i, cf) in enumerate(bond.cashflows.coupons)
      date_vec[i+1] = date(cf)
    end

    tenor = QuantJulia.Time.year_fraction(dc, issue_date, date(bond.cashflows.coupons[end]))
    println(@sprintf(" %.2f  | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f ",
            tenor, 100.0 * bond.cashflows.coupons[end].rate.rate, 100.0 * par_rate(yts, date_vec, dc), 100.0 * par_rate(esf_fitted_curve, date_vec, dc), 100.0 * par_rate(spf_fitted_curve, date_vec, dc),
            100.0 * par_rate(nsf_fitted_curve, date_vec, dc), 100.0 * par_rate(cbsf_fitted_curve, date_vec, dc), 100.0 * par_rate(sf_fitted_curve, date_vec, dc)))
  end
end


# interp = QuantJulia.Math.LogInterpolation()
# trait = Discount()
# bootstrap = IterativeBootstrap()
#
# yts = PiecewiseYieldCurve(issue_date, bonds, dc, interp, trait, 0.00000000001, bootstrap)
#
# solver = QuantJulia.Math.BrentSolver()
# solver2 = QuantJulia.Math.FiniteDifferenceNewtonSafe()
# calculate!(IterativeBootstrap(), yts, solver2, solver)
#
#
# # fitted bonds
# esf = ExponentialSplinesFitting(true, length(bonds))
# fitted_curve = FittedBondDiscountCurve(0, issue_date, calendar, bonds, dc, esf, 1e-10, 5000, 1.0)
# initialize!(fitted_curve)
# calculate!(fitted_curve)
