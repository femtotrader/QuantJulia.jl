include("src/QuantJulia.jl")
using QuantJulia

const numRows = 5
const numCols = 5
const swaptionVols = [0.1490, 0.1340, 0.1228, 0.1189, 0.1148, 0.1290, 0.1201, 0.1146, 0.1108, 0.1040, 0.1149, 0.1112, 0.1070, 0.1010, 0.0957, 0.1047, 0.1021, 0.0980, 0.0951, 0.1270, 0.1000, 0.0950, 0.0900, 0.1230, 0.1160]
const swaptionLengths = [Dates.Year(1), Dates.Year(2), Dates.Year(3), Dates.Year(4), Dates.Year(5)]

function generate_flatforward_ts{C <: QuantJulia.Time.BusinessCalendar}(cal::C, settlementDate::Date)
  flat_rate = Quote(0.04875825)

  ffts = FlatForwardTermStructure(settlementDate, cal, flat_rate, QuantJulia.Time.Actual365())

  return ffts
end

function calibrate_model{M <: ShortRateModel}(model::M, helpers::Vector{SwaptionHelper})
  om = QuantJulia.Math.LevenbergMarquardt()
  calibrate!(model, helpers, om, QuantJulia.Math.EndCriteria(400, 100, 1.0e-8, 1.0e-8, 1.0e-8))

  for i=1:numRows
    j = numCols - (i - 1)
    k = (i - 1) * numCols + j

    npv = model_value!(helpers[i])
    implied = implied_volatility!(helpers[i], npv, 1e-4, 1000, 0.05, 0.50)
    diff = implied - swaptionVols[k]

    println(@sprintf("%i x %i: model %.5f%%, market: %.5f%% (%.5f%%)", i, Int(swaptionLengths[j]), implied * 100, swaptionVols[k] * 100, diff * 100))
  end
end


function main()
  cal = QuantJulia.Time.TargetCalendar()
  settlementDate = Date(2002, 2, 19)
  todays_date = Date(2002, 2, 15)
  set_eval_date!(settings, todays_date)

  const swaptionMats = [Dates.Year(1), Dates.Year(2), Dates.Year(3), Dates.Year(4), Dates.Year(5)]

  # flat yield term strucutre implying 1x5 swap at 5%
  rhTermStructure = generate_flatforward_ts(cal, settlementDate)

  # Define the ATM/OTM/ITM swaps
  fixedLegFrequency = QuantJulia.Time.Annual()
  fixedLegConvention = QuantJulia.Time.Unadjusted()
  floatingLegConvention = QuantJulia.Time.ModifiedFollowing()
  fixedLegDayCounter = QuantJulia.Time.EuroThirty360()
  floatingLegFrequency = QuantJulia.Time.Semiannual()

  swapType = Payer()
  dummyFixedRate = 0.03
  indexSixMonths = euribor_index(QuantJulia.Time.TenorPeriod(Dates.Month(6)), rhTermStructure)

  startDate = QuantJulia.Time.advance(Dates.Year(1), cal, settlementDate, floatingLegConvention)
  maturity = QuantJulia.Time.advance(Dates.Year(5), cal, startDate, floatingLegConvention)

  fixedSchedule = QuantJulia.Time.Schedule(startDate, maturity, QuantJulia.Time.TenorPeriod(fixedLegFrequency), fixedLegConvention, fixedLegConvention, QuantJulia.Time.DateGenerationForwards(), false, cal)
  floatSchedule = QuantJulia.Time.Schedule(startDate, maturity, QuantJulia.Time.TenorPeriod(floatingLegFrequency), floatingLegConvention, floatingLegConvention, QuantJulia.Time.DateGenerationForwards(), false, cal)

  swap = VanillaSwap(swapType, 1000.0, fixedSchedule, dummyFixedRate, fixedLegDayCounter, indexSixMonths, 0.0, floatSchedule, indexSixMonths.dc, DiscountingSwapEngine(rhTermStructure))

  fixedATMRate = fair_rate(swap)
  fixedOTMRate = fixedATMRate * 1.2
  fixedITMRate = fixedATMRate * 0.8

  times = zeros(0)
  swaptions = Vector{SwaptionHelper}(numRows)

  for i = 1:numRows
    j = numCols - (i - 1)
    k = (i - 1) * numCols + j

    sh = SwaptionHelper(swaptionMats[i], swaptionLengths[j], Quote(swaptionVols[k]), indexSixMonths, indexSixMonths.tenor, indexSixMonths.dc, indexSixMonths.dc, rhTermStructure)

    times = add_times_to!(sh, times)
    swaptions[i] = sh
  end

  tg = QuantJulia.Time.TimeGrid(times, 30)

  # models
  modelG2 = G2(rhTermStructure)
  hullWhiteModel = HullWhite(rhTermStructure)

  for swaptionHelper in swaptions
    swaptionHelper.pricingEngine = G2SwaptionEngine(modelG2, 6.0, 16)
  end

  calibrate_model(modelG2, swaptions)
  println("calibrated to: ")
  println(@sprintf("a = %.6f, sigma = %.6f", get_params(modelG2)[1], get_params(modelG2)[2]))
  println(@sprintf("b = %.6f, eta = %.6f", get_params(modelG2)[3], get_params(modelG2)[4]))
  println(@sprintf("rho = %.6f", get_params(modelG2)[5]))

  # Hull White
  for swaptionHelper in swaptions
    update_pricing_engine!(swaptionHelper, JamshidianSwaptionEngine(hullWhiteModel))
  end

  calibrate_model(hullWhiteModel, swaptions)
  println("calibrated to: ")
  println(@sprintf("a = %.6f, sigma = %.6f", get_params(hullWhiteModel)[1], get_params(hullWhiteModel)[2]))
end
