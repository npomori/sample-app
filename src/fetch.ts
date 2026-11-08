import { App } from 'astro/app'
import { actions, middleware, pages } from 'astro/hono'
import { createParticipantFetch } from 'participant-app-base'

export default createParticipantFetch({
  App,
  middleware,
  actions,
  pages,
  mutations: [],
  routes() {}
})
