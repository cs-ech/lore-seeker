describe "Oversized cards" do
  include_context "db"

  it "is:oversized" do
    assert_search_equal "is:oversized", "t:plane or t:phenomenon or t:scheme or e:pcmd,oc13,oc14,oc15,oc16,oc17,oc18,ocm1,ocmd"
    assert_search_equal "not:oversized", "-(is:oversized)"
  end
end