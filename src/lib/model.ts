export type Settings={id:number;name:string;address:string;whatsapp:string;instagram:string;price:number;duration:number;enabled:boolean;logo:string;photos:string[]};
export type Hours={id:number;opens:string;closes:string;closed:boolean};
export type Customer={id:string;first_name:string;last_name:string;phone:string;created_at:string};
export type Appointment={id:string;customer_id:string;starts_at:string;ends_at:string;status:string;price:number;created_at:string};
export type Payment={id:string;appointment_id:string;customer_id:string;paid_at:string;amount:number;method:string;customer_name:string};
export type Notice={id:string;appointment_id:string;created_at:string;read_at:string|null;payload:{name:string;phone:string;starts_at:string;price:number}};
export type Block={id:string;starts_at:string;ends_at:string;reason:string};
export const defaults:Settings={id:1,name:"TT Peluquería",address:"Dardo Rocha 626, Rojas, Buenos Aires",whatsapp:"5492474472816",instagram:"https://www.instagram.com/peluqueria_tt/",price:0,duration:30,enabled:false,logo:"",photos:[]};
export const methods=["Efectivo","Transferencia","Mercado Pago","Tarjeta","Otro"];
export const statuses=["Reservado","Confirmado","Realizado","Cancelado","Ausente"];
export const days=["Domingo","Lunes","Martes","Miércoles","Jueves","Viernes","Sábado"];
export const money=(n:number)=>new Intl.NumberFormat("es-AR",{style:"currency",currency:"ARS",maximumFractionDigits:0}).format(n);
export const dayKey=(s:string|Date=new Date())=>new Intl.DateTimeFormat("en-CA",{timeZone:"America/Argentina/Buenos_Aires",year:"numeric",month:"2-digit",day:"2-digit"}).format(new Date(s));
export const time=(s:string)=>new Intl.DateTimeFormat("es-AR",{timeZone:"America/Argentina/Buenos_Aires",hour:"2-digit",minute:"2-digit",hour12:false}).format(new Date(s));
export const pretty=(s:string)=>new Intl.DateTimeFormat("es-AR",{timeZone:"America/Argentina/Buenos_Aires",day:"numeric",month:"long",year:"numeric"}).format(new Date(s.length===10?s+"T12:00:00-03:00":s));
export const shift=(d:string,n:number)=>{const x=new Date(d+"T12:00:00Z");x.setUTCDate(x.getUTCDate()+n);return x.toISOString().slice(0,10)};
export function summarize(payments:Payment[],from:string,to:string){
 const rows=payments.filter(p=>dayKey(p.paid_at)>=from&&dayKey(p.paid_at)<=to);
 return {rows,total:rows.reduce((s,p)=>s+Number(p.amount),0),cuts:rows.length,customers:new Set(rows.map(p=>p.customer_id)).size};
}
