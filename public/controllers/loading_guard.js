export class LoadingGuard {
  constructor({ onShow, onHide, delay = 200, minDuration = 500 }) {
    this.onShow = onShow
    this.onHide = onHide
    this.delay = delay
    this.minDuration = minDuration
    this.timer = null
    this.shownAt = null
  }

  show() {
    this.timer = setTimeout(() => {
      this.shownAt = Date.now()
      this.onShow()
    }, this.delay)
  }

  hide() {
    clearTimeout(this.timer)
    if (!this.shownAt) { this.onHide(); return }

    const remaining = Math.max(0, this.minDuration - (Date.now() - this.shownAt))
    this.shownAt = null
    if (remaining === 0) { this.onHide(); return }
    setTimeout(() => this.onHide(), remaining)
  }
}
