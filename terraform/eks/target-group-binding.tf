# TargetGroupBinding para sincronizar automáticamente los targets del ALB
# con los pods de ingress-nginx usando AWS Load Balancer Controller
resource "kubectl_manifest" "ingress_nginx_tgb" {
  yaml_body = <<-YAML
    apiVersion: elbv2.k8s.aws/v1beta1
    kind: TargetGroupBinding
    metadata:
      name: ingress-nginx-tgb
      namespace: ingress-nginx
    spec:
      serviceRef:
        name: ingress-nginx-controller
        port: 80
      targetGroupARN: ${aws_lb_target_group.ingress_nginx.arn}
      targetType: ip
      networking:
        ingress:
        - from:
          - securityGroup:
              groupID: ${aws_security_group.alb.id}
          ports:
          - protocol: TCP
            port: 80
  YAML

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.ingress_nginx
  ]
}
