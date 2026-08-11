export interface AuthenticatedIdentity {
  subject: string;
  roles: ReadonlySet<string>;
}
