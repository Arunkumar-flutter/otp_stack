/// The verification state of an `OtpStackField`.
///
/// The consumer app owns this state: it decides when to move from [idle] to
/// [verifying] (when the API request starts), to [success] (when the request
/// succeeds) or to [error] (when it fails). The package only reacts to the
/// transitions and plays the matching animation.
enum OtpStackStatus {
  /// The cards are shown as editable input fields.
  idle,

  /// The cards are fanned out and a rotating loading border is animating.
  verifying,

  /// The cards are stacked into a single card showing a checkmark.
  success,

  /// The cards briefly show the error state, then animate back to [idle] so
  /// the user can edit and retry.
  error,
}
