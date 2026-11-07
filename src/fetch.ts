import { App } from 'astro/app'
import { actions, middleware, pages } from 'astro/hono'
import { createParticipantFetch } from 'astro-participant-auth'

export default createParticipantFetch({
  App,
  middleware,
  actions,
  pages,
  mutations: [],
  routes() {}
})
