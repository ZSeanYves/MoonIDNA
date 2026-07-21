///|
/// Legacy compatibility entry point. New code should import `/idna` and handle
/// `IdnaError` from `to_ascii` explicitly.
#deprecated("Use @idna.to_ascii from ZSeanYves/MoonIDNA/idna")
pub fn to_ascii(domain : StringView) -> String {
  @idna.to_ascii(domain) catch {
    _ => domain.to_owned()
  }
}

///|
#deprecated("Use @idna.to_unicode from ZSeanYves/MoonIDNA/idna")
pub fn to_unicode(domain : StringView) -> String {
  @idna.to_unicode(domain)
}

///|
#deprecated("Pass transitional_processing=true to @idna.to_ascii")
pub fn to_ascii_transitional(domain : StringView) -> String {
  @idna.to_ascii(domain, transitional_processing=true) catch {
    _ => domain.to_owned()
  }
}

///|
#deprecated("Pass transitional_processing=true to @idna.to_unicode")
pub fn to_unicode_transitional(domain : StringView) -> String {
  @idna.to_unicode(domain, transitional_processing=true)
}
