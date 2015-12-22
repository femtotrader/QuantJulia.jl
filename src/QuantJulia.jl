# QuantJulia

module QuantJulia

# functions overridden from based
import Base.findprev, Base.findnext

function findprev(testf::Function, A, start::Integer, val)
  for i = start:-1:1
    testf(A[i], val) && return i
  end
  0
end

function findnext(testf::Function, A, start::Integer, val)
  for i = start:length(A)
    if testf(A[i], val)
      return i
    end
  end
  return 0
end

# Time module
include("time/Time.jl")

# Math module
include("math/Math.jl")

# MAIN MODULE CODE

export
    # abstract_types.jl
    CompoundingType, TermStructure, YieldTermStructure, InterpolatedCurve, BootstrapTrait, Bootstrap,
    FittingMethod, CashFlows, CashFlow, Coupon, Instrument, Bond, PricingEngine, Duration, RateHelper,
    InterestRateIndex, AbstractCurrency,

    # quotes/Quotes.jl
    Quote,

    # currencies/currencies.jl
    NullCurrency, Currency,

    # InterestRates.jl
    ContinuousCompounding, SimpleCompounding, CompoundedCompounding, SimpleThenCompounded, ModifiedDuration,
    InterestRate, discount_factor, compound_factor, equivalent_rate, implied_rate,

    # Indexes
    IborIndex, fixing_date, maturity_date, fixing, forecast_fixing,

    # termstructures/yield_term_structure.jl
    FlatForwardTermStructure, JumpDate, JumpTime,
    calculated!, check_range, max_date, time_from_reference, discount, zero_rate, forward_rate, discount_impl,

    # termstructures/curve.jl
    PiecewiseYieldCurve, FittedBondDiscountCurve, FittingCost, NullCurve,
    max_date, discount, calculate!, initialize!, value,

    # termstructures/bootstrap.jl
    Discount, guess, min_value_after, max_value_after,
    IterativeBootstrap, initialize, quote_error,

    # termstructures/nonlinear_fitting_methods.jl
    ExponentialSplinesFitting, SimplePolynomialFitting, NelsonSiegelFitting, SvenssonFitting, CubicBSplinesFitting, discount_function, guess_size,

    # cash_flows/cash_flows.jl
    SimpleCashFlow, FixedRateCoupon, Leg, FixedRateLeg, ZeroCouponLeg, IRRFinder, operator, amount, date, duration, yield, previous_cashflow_date,
    accrual_days, accrual_days, next_cashflow, has_occurred,

    # instruments/bond.jl
    FixedRateBond, ZeroCouponBond, value, get_settlement_date, notional, accrued_amount, yield, duration, npv, 
    # instruments/rate.jl
    DepositRate,

    # termstructures/bond_helpers.jl
    implied_quote, clean_price, dirty_price, settlement_date,

    # termstructures/rate_helpers.jl
    implied_quote,

    # pricing_engines/pricing_engines.jl
    DiscountingBondEngine, calculate

# abstract types
include("abstract_types.jl")

# Quotes ----------------------------
include("quotes/Quotes.jl")

# Currencies -----------------------
include("currencies/currencies.jl")

# Interest Rates ---------------------------------
include("InterestRates.jl")

# Indexes
include("indexes/indexes.jl")

# Term Structures -----------------------------------
# yield term structures
include("termstructures/yield_term_structure.jl")
# Curves
include("termstructures/curve.jl")
# bootstrapping
include("termstructures/bootstrap.jl")

# Cash Flows ------------------------------------
include("cash_flows/cash_flows.jl")

# Instruments ------------------------
# bond
include("instruments/bond.jl")
include("instruments/rate.jl")

# helpers
include("termstructures/bond_helpers.jl")
include("termstructures/rate_helpers.jl")

# nonlinear fitting methods
include("termstructures/nonlinear_fitting_methods.jl")

# Pricing Engines ------------------------
include("pricing_engines/pricing_engines.jl")

# # Helpers NOW IN TERM STRUCTURE
# include("helpers/bond_helpers.jl")

type Settings
  evaluation_date::Date
end

settings = Settings(Date())

function set_eval_date!(sett::Settings, d::Date)
  sett.evaluation_date = d
end

export Settings, settings, set_eval_date!

end
