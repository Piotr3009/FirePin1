import { redirect } from 'next/navigation'

export default function Home() {
  // Authenticated users land on their projects; the middleware bounces
  // unauthenticated users to /login.
  redirect('/projects')
}
