import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class OtoCard extends StatelessWidget {
  const OtoCard({super.key,required this.child,this.padding=const EdgeInsets.all(14),this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  @override Widget build(BuildContext context){
    final colors=Theme.of(context).colorScheme;
    final body=Container(padding:padding,decoration:BoxDecoration(color:colors.surfaceContainer,borderRadius:BorderRadius.circular(16),border:Border.all(color:colors.outlineVariant)),child:child);
    return onTap==null?body:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(16),child:body);
  }
}

class OtoStatusBadge extends StatelessWidget {
  const OtoStatusBadge({super.key,required this.label,required this.color,this.icon});
  final String label; final Color color; final IconData? icon;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:color.withValues(alpha:.14),borderRadius:BorderRadius.circular(9),border:Border.all(color:color.withValues(alpha:.35))),child:Row(mainAxisSize:MainAxisSize.min,children:[if(icon!=null)...[Icon(icon,size:12,color:color),const SizedBox(width:4)],Text(label,style:TextStyle(color:color,fontSize:8,fontWeight:FontWeight.w900))]));
}

class OtoEmptyState extends StatelessWidget {
  const OtoEmptyState({super.key,required this.icon,required this.title,required this.body,this.actionLabel,this.onAction});
  final IconData icon; final String title,body; final String? actionLabel; final VoidCallback? onAction;
  @override Widget build(BuildContext context)=>OtoCard(child:Column(children:[Container(width:52,height:52,decoration:BoxDecoration(color:AppColors.accentSoft,borderRadius:BorderRadius.circular(16)),child:Icon(icon,color:AppColors.accentBright,size:28)),const SizedBox(height:11),Text(title,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15)),const SizedBox(height:5),Text(body,textAlign:TextAlign.center,style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant,fontSize:10.5,height:1.4)),if(actionLabel!=null&&onAction!=null)...[const SizedBox(height:13),SizedBox(width:double.infinity,height:46,child:FilledButton.icon(onPressed:onAction,icon:const Icon(Icons.arrow_forward_rounded),label:Text(actionLabel!,style:const TextStyle(fontWeight:FontWeight.w900))))]]));
}
