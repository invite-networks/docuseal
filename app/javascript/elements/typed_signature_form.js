import { target, targetable } from '@github/catalyst/lib/targetable'

export default targetable(class extends HTMLElement {
  static [target.static] = ['input', 'preview']

  connectedCallback () {
    this.loadFont()
    this.input.addEventListener('input', this.updatePreview)
    this.updatePreview()
  }

  disconnectedCallback () {
    this.input.removeEventListener('input', this.updatePreview)
  }

  updatePreview = () => {
    this.preview.textContent = this.input.value || '\u00a0'
  }

  async loadFont () {
    try {
      const font = new FontFace(this.dataset.fontFamily, `url(${this.dataset.fontUrl})`)
      const loadedFont = await font.load()

      document.fonts.add(loadedFont)
      this.preview.style.fontFamily = `"${this.dataset.fontFamily}"`
    } catch (error) {
      console.warn('Typed signature preview font could not be loaded.', error)
    }
  }
})
