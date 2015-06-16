class GraphsController < ApplicationController
  before_filter :login_required

  def show
    respond_to do |format|
      format.html
      format.png do
        path = Pathname.new("/vagrant/hawk/tmp").join(
          Dir::Tmpname.make_tmpname(
            ["graph", ".png"],
            nil
          )
        )

        begin
          res = Invoker.instance.crm(
            "configure",
            "graph",
            "dot",
            path.to_s,
            "png"
          )

          if res == true
            send_data(
              path.read,
              type: "image/png",
              disposition: "inline"
            )
          else
            Rails.logger.warn("%s, failed to generate graph" % res)

            send_data(
              Rails.root.join(
                "app",
                "assets",
                "images",
                "misc",
                "blank.png"
              ).read,
              type: "image/png",
              disposition: "inline"
            )
          end
        ensure
          File.unlink path if File.exist? path
        end
      end
    end
  end
end
