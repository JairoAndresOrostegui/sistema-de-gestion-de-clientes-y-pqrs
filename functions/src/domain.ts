import {DateTime} from 'luxon';
import {z} from 'zod';

export const roleSchema = z.enum(['owner', 'commercial', 'client', 'technician', 'reader']);
export type Role = z.infer<typeof roleSchema>;
export type Actor = {uid: string; email: string; role: Role; permissions: string[]; device?: {sessionId:string;slot:string;platform:string;label:string;installationId:string}|null};
export const id = z.string().regex(/^[a-zA-Z0-9_-]{1,128}$/);
export const text = z.string().trim().max(12000);
export const name = z.string().trim().min(1).max(180);
export const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(v => DateTime.fromISO(v).isValid, 'Fecha inválida');
export const audienceSchema = z.enum(['public', 'internal', 'technical']);
export const statuses = ['nuevo','clasificacion','esperando_cliente','primer_nivel','escalado','analisis','ejecucion','resuelto','cerrado','reabierto','cancelado'] as const;
export type TicketStatus = typeof statuses[number];
export const transitions: Record<TicketStatus, TicketStatus[]> = {
  nuevo: ['clasificacion','primer_nivel','cancelado'], clasificacion: ['primer_nivel','escalado','esperando_cliente','cancelado'],
  primer_nivel: ['esperando_cliente','escalado','resuelto','cancelado'], escalado: ['analisis','primer_nivel','esperando_cliente'],
  analisis: ['ejecucion','esperando_cliente','primer_nivel','resuelto'], ejecucion: ['esperando_cliente','resuelto','escalado'],
  esperando_cliente: ['clasificacion','primer_nivel','analisis','ejecucion','cancelado'], resuelto: ['cerrado','reabierto'],
  cerrado: ['reabierto'], reabierto: ['clasificacion','primer_nivel','escalado'], cancelado: ['reabierto'],
};
export function canTransition(role: Role, from: TicketStatus, to: TicketStatus) {
  if (!transitions[from]?.includes(to)) return false;
  if (role === 'client') return (from === 'resuelto' && to === 'cerrado') || (['resuelto','cerrado'].includes(from) && to === 'reabierto');
  return role !== 'reader';
}
export function hasPermission(a: Actor, permission: string) {
  if (a.role === 'owner') return true;
  if (permission === 'technical') return a.role === 'technician' && a.permissions.includes(permission);
  if (permission === 'manageAccess') return false;
  return a.role === 'commercial' || a.permissions.includes(permission);
}
export const policySchema = z.object({
  timezone: z.string().default('America/Bogota').refine(v=>DateTime.now().setZone(v).isValid),
  weekdays: z.array(z.number().int().min(1).max(7)).min(1).default([1,2,3,4,5]),
  startHour: z.number().int().min(0).max(22).default(8), endHour: z.number().int().min(1).max(24).default(17),
  holidays: z.array(date).max(366).default([]), responseMinutes: z.number().int().min(1).max(525600).default(240),
  resolutionMinutes: z.number().int().min(1).max(525600).default(1440),
}).refine(p => p.endHour > p.startHour, 'El horario final debe ser posterior al inicial');
export type SlaPolicy = z.infer<typeof policySchema>;
export function businessDeadline(start: string, minutes: number, policy: SlaPolicy): string {
  let t = DateTime.fromISO(start, {setZone:true}).setZone(policy.timezone);
  let left = minutes;
  for (let i=0; i<4000; i++) {
    const day = t.startOf('day');
    const begin = day.plus({hours:policy.startHour});
    const end = day.plus({hours:policy.endHour});
    if (!policy.weekdays.includes(t.weekday) || policy.holidays.includes(t.toISODate()!)) { t=day.plus({days:1}); continue; }
    if (t < begin) t=begin;
    if (t >= end) {t=day.plus({days:1}); continue;}
    const available = end.diff(t,'minutes').minutes;
    if (left <= available) return t.plus({minutes:left}).toUTC().toISO()!;
    left -= available; t=day.plus({days:1});
  }
  throw new Error('El SLA excede el horizonte de cálculo');
}
export function businessMinutes(from:string, to:string, p:SlaPolicy) {
  let t=DateTime.fromISO(from).setZone(p.timezone);
  const finish=DateTime.fromISO(to).setZone(p.timezone); let total=0;
  for(let i=0;i<4000 && t<finish;i++) {
    const day=t.startOf('day'); const end=day.plus({hours:p.endHour});
    if(p.weekdays.includes(t.weekday)&&!p.holidays.includes(t.toISODate()!)) {
      const begin=DateTime.max(t,day.plus({hours:p.startHour}));
      total+=Math.max(0,DateTime.min(end,finish).diff(begin,'minutes').minutes);
    } t=day.plus({days:1});
  } return total;
}
export function reminderKey(kind:string, entityId:string, dueDate:string, days:number) {return `${kind}_${entityId}_${dueDate}_${days}`;}
export function daysUntil(due:string, now:DateTime=DateTime.now(), timezone='America/Bogota') { return Math.round(DateTime.fromISO(due,{zone:timezone}).startOf('day').diff(now.setZone(timezone).startOf('day'),'days').days); }
export function csvCell(value: unknown) { let v=String(value??''); if (/^[=+\-@\t\r]/.test(v)) v="'"+v; return '"'+v.replaceAll('"','""')+'"'; }

export const projectSchema = z.object({companyId:id,name, description:text.default(''), type:text.default('Software'), productId:text.default(''), objective:text.default(''), scope:text.default(''), status:z.enum(['negociacion','contratado','desarrollo','implementacion','activo','mantenimiento','suspendido','finalizado']).default('negociacion'), version:text.default(''), environment:text.default('QA'), technicalOwner:text.default(''), commercialOwner:text.default(''), startDate:date.optional(), endDate:date.optional()});
export const companySchema = z.object({name, legalName:text.default(''),nit:text.default(''),sector:text.default(''),description:text.default(''),address:text.default(''),email:z.union([z.string().email(),z.literal('')]).default(''),phone:text.default(''),website:text.default(''),hours:text.default(''),timezone:z.string().default('America/Bogota'),status:z.enum(['prospecto','activo','inactivo']).default('activo'),tags:z.array(name).max(30).default([])});
export const contactSchema=z.object({companyId:id,projectId:id.optional(),name,position:text.default(''),area:text.default(''),parentArea:text.default(''),branch:text.default(''),email:text.default(''),phone:text.default(''),availability:text.default(''),responsibilities:text.default(''),preferredContact:text.default(''),primary:z.boolean().default(false)});
export const ticketSchema = z.object({companyId:id,projectId:id,subject:name,description:text.min(5),category:z.enum(['peticion','queja','reclamo','sugerencia','incidente','soporte','consulta','capacitacion','mejora']),impact:z.enum(['bajo','medio','alto','critico']).default('medio'),featureIds:z.array(id).max(10).default([]),version:text.default(''),environment:text.default(''),steps:text.default(''),expected:text.default(''),actual:text.default(''),contact:text.default(''),visibility:z.enum(['project','requester']).default('project')});
export const catalogSchema=z.object({companyId:id,projectId:id,name,module:text.default('General'),description:text.default(''),faq:text.default(''),roles:text.default(''),version:text.default(''),status:z.enum(['disponible','planificado','retirado']).default('disponible'),published:z.boolean().default(false)});
export const articleSchema=z.object({companyId:id,projectId:id,name,description:text,version:text.default(''),published:z.boolean().default(false)});
export const eventSchema=z.object({companyId:id,projectId:id,name,type:z.enum(['tarea','hito','capacitacion','visita','reunion','despliegue','compromiso']).default('tarea'),description:text.default(''),dueDate:date,owner:text.default(''),attendees:text.default(''),materials:text.default(''),version:text.default(''),status:z.enum(['pendiente','en_curso','completado','cancelado']).default('pendiente'),published:z.boolean().default(false)});
export const contractSchema=z.object({companyId:id,projectId:id,name,type:z.enum(['venta','implementacion','soporte','mantenimiento','hosting','dominio','otro']).default('soporte'),description:text.default(''),startDate:date,endDate:date,amount:z.number().min(0).default(0),currency:z.enum(['COP','USD','EUR']).default('COP'),periodicity:text.default('anual'),paymentTerms:text.default(''),signatories:text.default(''),signatureDate:date.optional(),version:text.default('1'),status:z.enum(['borrador','activo','vencido','renovado','cancelado']).default('activo'),channels:text.default('Portal'),exclusions:text.default(''),hoursIncluded:z.number().min(0).default(0),sla:policySchema.optional(),published:z.boolean().default(false)}).refine(v=>v.endDate>=v.startDate,'La vigencia final debe ser posterior a la inicial');
export const serviceSchema=z.object({companyId:id,projectId:id,name,type:z.enum(['dominio','dns','hosting','vps','base_datos','correo','ssl','licencia','api','soporte','otro']).default('hosting'),provider:text.default(''),reference:text.default(''),owner:text.default(''),ownership:text.default('Cliente'),cost:z.number().min(0).default(0),price:z.number().min(0).default(0),currency:z.enum(['COP','USD','EUR']).default('COP'),periodicity:text.default('anual'),startDate:date,endDate:date,status:z.enum(['activo','vencido','renovado','cancelado']).default('activo'),paymentReference:text.default(''),secretReference:text.default(''),notes:text.default(''),url:text.default(''),published:z.boolean().default(false)}).refine(v=>v.endDate>=v.startDate,'Vigencia inválida');
export const financeSchema=z.object({companyId:id,projectId:id,name,type:z.enum(['ingreso','gasto','participacion']),amount:z.number().min(0),currency:z.enum(['COP','USD','EUR']).default('COP'),date:date,description:text.default('')});
export const installationSchema=z.object({companyId:id,projectId:id,name,version:name,environment:z.enum(['desarrollo','qa','produccion']).default('qa'),branch:text.default(''),url:text.default(''),deployedAt:date,description:text.default(''),published:z.boolean().default(false)});
export const productSchema=z.object({name,description:text.default(''),version:text.default(''),status:z.enum(['activo','mantenimiento','retirado']).default('activo')});
export const schemas={companies:companySchema,projects:projectSchema,contacts:contactSchema,catalog:catalogSchema,articles:articleSchema,events:eventSchema,contracts:contractSchema,services:serviceSchema,finance:financeSchema,installations:installationSchema,products:productSchema};
