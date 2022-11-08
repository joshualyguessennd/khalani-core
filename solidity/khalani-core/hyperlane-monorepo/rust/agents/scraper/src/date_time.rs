//! A set of tools for working with the sea_orm date/time types.

use std::time::{SystemTime, UNIX_EPOCH};

use chrono::{Datelike, NaiveDateTime, Timelike};
use sea_orm::prelude::{TimeDate, TimeDateTime, TimeTime};

pub fn from_date_time_like(dt: &(impl Datelike + Timelike)) -> TimeDateTime {
    let date = TimeDate::from_ordinal_date(dt.year(), dt.ordinal() as u16).unwrap();
    let time = TimeTime::from_hms_nano(
        dt.hour() as u8,
        dt.minute() as u8,
        dt.second() as u8,
        dt.nanosecond(),
    )
    .unwrap();
    TimeDateTime::new(date, time)
}

/// Convert a std `SystemTime` to a sea_orm `TimeDateTime` object.
///
/// Can I just say: This should not need to exist.
/// TODO: raise a PR for `impl From<SystemTime> for TimeDateTime` because WTF.
/// TODO: raise a PR for `impl From<chrono::DateTime> for TimeDateTime` also
/// because WTF.
pub fn from_system_time(sys: &SystemTime) -> TimeDateTime {
    let dur = sys.duration_since(UNIX_EPOCH).unwrap();
    let naive = NaiveDateTime::from_timestamp(dur.as_secs() as i64, dur.subsec_nanos());
    from_date_time_like(&naive)
}

pub fn now() -> TimeDateTime {
    from_system_time(&SystemTime::now())
}
