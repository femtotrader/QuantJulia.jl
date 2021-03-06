type IborIndex{S <: AbstractString, I <: Integer, B <: BusinessCalendar, C <: BusinessDayConvention, DC <: DayCount, T <: TermStructure} <: InterestRateIndex
  familyName::S
  tenor::TenorPeriod
  fixingDays::I
  currency::AbstractCurrency
  fixingCalendar::B
  convention::C
  endOfMonth::Bool
  dc::DC
  ts::T

  call{S, I, B, C, DC}(::Type{IborIndex}, familyName::S, tenor::TenorPeriod, fixingDays::I, currency::AbstractCurrency, fixingCalendar::B,
                                convention::C, endOfMonth::Bool, dc::DC) =
    new{S, I, B, C, DC, TermStructure}(familyName, tenor, fixingDays, currency, fixingCalendar, convention, endOfMonth, dc)

  call{S, I, B, C, DC, T}(::Type{IborIndex}, familyName::S, tenor::TenorPeriod, fixingDays::I, currency::AbstractCurrency, fixingCalendar::B,
                                convention::C, endOfMonth::Bool, dc::DC, ts::T) =
    new{S, I, B, C, DC, T}(familyName, tenor, fixingDays, currency, fixingCalendar, convention, endOfMonth, dc, ts)
end

type LiborIndex{S <: AbstractString, I <: Integer, B <: BusinessCalendar, C <: BusinessDayConvention, DC <: DayCount, T <: TermStructure} <: InterestRateIndex
  familyName::S
  tenor::TenorPeriod
  fixingDays::I
  currency::Currency
  fixingCalendar::B
  jointCalendar::JointCalendar
  convention::C
  endOfMonth::Bool
  dc::DC
  ts::T

  call{S, I, B, C, DC}(::Type{LiborIndex}, familyName::S, tenor::TenorPeriod, fixingDays::I, currency::Currency, fixingCalendar::B,
                                jointCalendar::JointCalendar, convention::C, endOfMonth::Bool, dc::DC) =
    new{S, I, B, C, DC, TermStructure}(familyName, tenor, fixingDays, currency, fixingCalendar, jointCalendar, convention, endOfMonth, dc)
end

function LiborIndex{S <: AbstractString, I <: Integer, B <: BusinessCalendar, DC <: DayCount}(familyName::S,
                    tenor::TenorPeriod, fixingDays::I, currency::Currency, fixingCalendar::B, dc::DC)
  endOfMonth = libor_eom(tenor.period)
  conv = libor_conv(tenor.period)
  jc = JointCalendar(QuantJulia.Time.UKLSECalendar(), fixingCalendar)

  return LiborIndex(familyName, tenor, fixingDays, currency, fixingCalendar, jc, conv, endOfMonth, dc)
end



fixing_date{I <: InterestRateIndex}(idx::I, d::Date) = advance(Dates.Day(-idx.fixingDays), idx.fixingCalendar, d, idx.convention)
maturity_date(idx::IborIndex, d::Date) = advance(idx.tenor.period, idx.fixingCalendar, d, idx.convention)
value_date{I <: InterestRateIndex}(idx::I, d::Date) = advance(Dates.Day(idx.fixingDays), idx.fixingCalendar, d, idx.convention)

function fixing{I <: InterestRateIndex, T <: TermStructure}(idx::I, ts::T, _fixing_date::Date, forecast_todays_fixing::Bool=true)
  today = settings.evaluation_date
  if _fixing_date > today || (_fixing_date == today && forecast_todays_fixing)
    return forecast_fixing(idx, ts, _fixing_date)
  end

  error("Not yet implemented for older dates than eval date")
end

function forecast_fixing{X <: InterestRateIndex, T <: TermStructure}(idx::X, ts::T, _fixing_date::Date)
  d1 = value_date(idx, _fixing_date)
  d2 = maturity_date(idx, d1)
  t = year_fraction(idx.dc, d1, d2)
  return forecast_fixing(idx, ts, d1, d2, t)
end

function forecast_fixing{X <: InterestRateIndex, T <: TermStructure}(idx::X, ts::T, d1::Date, d2::Date, t::Float64)
  disc1 = discount(ts, d1)
  disc2 = discount(ts, d2)

  return (disc1 / disc2 - 1.0) / t
end

# Libor methods
function value_date(idx::LiborIndex, d::Date)
  new_d = advance(Dates.Day(idx.fixingDays), idx.fixingCalendar, d, idx.convention)
  return adjust(idx.jointCalendar, idx.convention, new_d)
end

maturity_date(idx::LiborIndex, d::Date) = advance(idx.tenor.period, idx.jointCalendar, d, idx.convention)

# types of indexes
euribor_index(tenor::TenorPeriod) = IborIndex("Euribor", tenor, 2, EURCurrency(), QuantJulia.Time.TargetCalendar(), euribor_conv(tenor.period), euribor_eom(tenor.period), QuantJulia.Time.Actual360())
euribor_index{T <: TermStructure}(tenor::TenorPeriod, ts::T) = IborIndex("Euribor", tenor, 2, EURCurrency(), QuantJulia.Time.TargetCalendar(), euribor_conv(tenor.period), euribor_eom(tenor.period), QuantJulia.Time.Actual360(), ts)

function usd_libor_index(tenor::TenorPeriod)
  return LiborIndex("USDLibor", tenor, 2, USDCurrency(), QuantJulia.Time.USSettlementCalendar(), QuantJulia.Time.Actual360())
end

euribor_conv(::Union{Base.Dates.Day, Base.Dates.Week}) = QuantJulia.Time.Following()
euribor_conv(::Union{Base.Dates.Month, Base.Dates.Year}) = QuantJulia.Time.ModifiedFollowing()

euribor_eom(::Union{Base.Dates.Day, Base.Dates.Week}) = false
euribor_eom(::Union{Base.Dates.Month, Base.Dates.Year}) = true

libor_conv(::Union{Base.Dates.Day, Base.Dates.Week}) = QuantJulia.Time.Following()
libor_conv(::Union{Base.Dates.Month, Base.Dates.Year}) = QuantJulia.Time.ModifiedFollowing()

libor_eom(::Union{Base.Dates.Day, Base.Dates.Week}) = false
libor_eom(::Union{Base.Dates.Month, Base.Dates.Year}) = true
